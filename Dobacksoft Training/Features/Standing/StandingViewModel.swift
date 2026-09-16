import SwiftUI

/// El estado de «Mi posición»: la clasificación del aspirante en una
/// convocatoria, con su caché y su último dato bueno.
@MainActor
@Observable
final class StandingViewModel {
    /// Deliberadamente **sin `Equatable`**.
    ///
    /// La auditoría proponía hacerlo para poder animar con
    /// `.animation(_:value:)`, y eso habría arrastrado a `StandingDTO` y de ahí
    /// a media capa de modelos: trabajo real en tipos que no lo necesitan para
    /// nada más. Se anima sobre `phase`, que no lleva el dato dentro.
    enum State {
        case loading
        case loaded(StandingDTO)

        /// Lo último que se pudo leer, en un arranque sin red.
        ///
        /// Estado propio y no un `.loaded` con un DTO fabricado: de la caché se
        /// guarda una PROYECCIÓN, así que la pantalla puede enseñar menos que
        /// con red. Disfrazarla de DTO pediría inventar los campos que no se
        /// guardan, y esta app no inventa datos.
        case cached(StandingCache, capturedAt: Date)
        /// Con el motivo: no estar inscrito y no tener posición todavía son
        /// estados legítimos, no fallos, y se cuentan distinto.
        case notFound(NotFoundReason)
        case error(String)
    }

    var state: State = .loading

    /// La fase, para animar el cambio sin animar cada cifra. Ver `ScreenPhase`.
    var phase: ScreenPhase {
        switch state {
        case .loading:  .loading
        case .loaded:   .loaded
        case .cached:   .cached
        case .notFound: .empty
        case .error:    .error
        }
    }

    /// Hay un refresco en curso SOBRE datos ya visibles.
    ///
    /// Distinto de `.loading`: ahí no hay nada que enseñar y toca la pantalla
    /// de carga; aquí la posición sigue en pantalla y lo único que procede es
    /// un indicador discreto.
    var isRefreshing = false

    /// El fallo del último refresco, cuando había datos que conservar.
    ///
    /// Aparte de `.error` a propósito: `.error` significa «no hay nada que
    /// enseñar», y esto significa «lo que hay es de antes». Meterlos en el
    /// mismo sitio es lo que hacía que un fallo de red pasajero borrase la nota
    /// que el aspirante estaba mirando.
    var refreshError: String?

    /// Cuándo se obtuvieron los datos que se están enseñando.
    ///
    /// La hora del DATO, no la del último intento de refrescarlo: si el
    /// refresco falla no se mueve, porque lo que hay en pantalla sigue siendo
    /// lo de antes.
    var lastUpdated: Date?

    private let api: TrainingAPI
    private let now: @Sendable () -> Date

    private let lastGood: LastGoodStore

    init(
        api: TrainingAPI = APIClient.shared,
        now: @escaping @Sendable () -> Date = Date.init,
        lastGood: LastGoodStore = .appContainer
    ) {
        self.api = api
        self.now = now
        self.lastGood = lastGood
    }

    /// Lo último que se pudo leer, si sirve.
    ///
    /// `nil` cuando no hay nada, cuando no se pudo leer o cuando está caducada:
    /// en los tres casos el error es la respuesta honesta. Una caché de más de
    /// 48 horas no se enseña como dato vigente — mismo umbral que el widget,
    /// que se niega a mostrar un puesto de anteanoche sin etiquetarlo.
    private func cachedState(auth: AuthSession) -> State? {
        guard let userId = auth.user?.id else { return nil }
        guard case let .presente(cache, capturedAt) = lastGood.read(
            StandingCache.self, key: .standing, userId: userId, now: now()
        ) else { return nil }
        guard cache.isReadable else { return nil }
        return .cached(cache, capturedAt: capturedAt)
    }

    func load(
        convocatoriaId: String,
        auth: AuthSession,
        convocatoriaName: String? = nil,
        finality: GradeFinality = .unknown
    ) async {
        // Solo `.loaded` cuenta como «hay algo que proteger». `.notFound` es
        // una respuesta legítima, no un dato: conservarla ante un fallo
        // posterior enseñaría como vigente una ausencia que ya no consta.
        let teniaDatos: Bool
        if case .loaded = state { teniaDatos = true } else { teniaDatos = false }

        if teniaDatos { isRefreshing = true } else { state = .loading }
        defer { isRefreshing = false }

        do {
            let standing = try await auth.authorized { [api] token in
                try await api.standing(
                    convocatoriaId: convocatoriaId,
                    accessToken: token
                )
            }
            state = .loaded(standing)
            refreshError = nil
            lastUpdated = now()

            // La caché de arranque sin cobertura. Escribir es lo ÚLTIMO que
            // puede romper una carga que salió bien: `write` devuelve `false`
            // y no lanza.
            if let userId = auth.user?.id {
                lastGood.write(
                    StandingCache(
                        convocatoriaName: convocatoriaName,
                        position: standing.position,
                        totalParticipants: standing.totalCandidates,
                        score: standing.score,
                        finality: finality.persisted
                    ),
                    key: .standing,
                    userId: userId,
                    at: now()
                )
            }
        } catch let err as APIError where err.notFoundReason != nil {
            // **Una respuesta no es una ausencia.** «No está inscrito» es un
            // hecho del backend, y enseñar la caché encima diría que sigue
            // inscrito cuando ya no lo está.
            state = .notFound(err.notFoundReason ?? .resourceMissing)
        } catch {
            // Una cancelación no es un fallo que contar: cambiar de
            // convocatoria a media carga cancela la anterior, y pintar su error
            // culparía al aspirante de algo que hizo la app.
            guard !Task.isCancelled, !error.isCancellation else { return }
            let mensaje = (error as? APIError)?.userMessage ?? error.localizedDescription
            if teniaDatos {
                refreshError = "\(mensaje) Se muestra el último dato consultado."
            } else {
                state = cachedState(auth: auth) ?? .error(mensaje)
            }
        }

        // La convocatoria queda anotada para poder republicar al volver al
        // frente sin obligar a nadie a entrar aquí. Solo con datos: apuntar la
        // convocatoria de una carga fallida haría que el republicado pidiera
        // una posición que no existe.
        if case .loaded = state {
            SnapshotPublisher.shared.lastStandingConvocatoriaId = convocatoriaId
            SnapshotPublisher.shared.lastStandingConvocatoriaName = convocatoriaName
        }

        // La vista rápida se alimenta desde aquí. Un estado de error no
        // publica: un fallo de red pasajero no debe borrar el último dato bueno.
        if let content = SnapshotPublisher.content(
            for: state,
            convocatoriaName: convocatoriaName,
            finality: finality
        ) {
            SnapshotPublisher.shared.publish(content)
        }
    }
}
