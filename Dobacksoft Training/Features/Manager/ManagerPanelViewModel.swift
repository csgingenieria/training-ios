import SwiftUI
import os

/// El estado del panel del instructor.
///
/// Agrega dos peticiones en paralelo, indexa el censo de aspirantes leyendo
/// rankings con un tope, y acumula los fallos parciales sin tumbar la
/// pantalla. Era la superficie con más lógica de su área y la única sin
/// pruebas de comportamiento, porque usaba el cliente compartido y el doble
/// de red no podía responderle. Ahora lo recibe por parámetro, y
/// `ManagerPanelViewModelTests` lo ejercita.
@MainActor
@Observable
final class ManagerPanelViewModel {
    enum State {
        case loading
        case loaded(ManagerDashboardDTO, [ConvocatoriaSummaryDTO])
        case error(String)
    }

    var state: State = .loading

    // Sync de flota (POST /me/webfleet/sync) — feedback inline + sheet.
    var isSyncing: Bool = false
    var syncResult: SyncResultDTO?
    var syncErrorMessage: String?

    /// Inscritos que todavía no han conducido ningún recorrido, con la
    /// convocatoria a la que pertenecen.
    ///
    /// Es la lista que dirige el día del instructor y la web la tiene en su
    /// panel. No hace falta endpoint nuevo: el backend emite `position: null`
    /// exactamente para quien no ha conducido, así que el ranking ya lo dice.
    var pendientes: [Aspirante] { aspirantes.filter { !$0.haConducido } }

    /// Todos los inscritos de las convocatorias consultadas.
    ///
    /// Alimenta dos cosas con una sola lectura: la lista de quién no ha
    /// conducido y el buscador. Llegar a la ficha de alguien exigía saber su
    /// puesto y abrir el ranking; con esto se busca por nombre o por plaza.
    var aspirantes: [Aspirante] = []

    /// Qué parte del censo se pudo indexar.
    ///
    /// El índice sale de leer rankings, y eso puede quedarse corto por el tope
    /// de consultas o por un fallo de red. Sin este dato la app diría «ningún
    /// aspirante coincide» y «sin conducir: 18» como si fueran hechos, cuando
    /// son el resultado de no haber mirado. Afirmar un número sobre un grupo de
    /// personas que no se ha medido es justo lo que este proyecto no hace.
    struct IndexCoverage: Equatable {
        var consultadas: Int = 0
        var disponibles: Int = 0
        var fallidas: Int = 0

        var esCompleta: Bool { fallidas == 0 && consultadas >= disponibles }

        var aviso: String? {
            guard !esCompleta else { return nil }
            // Fallaron TODAS las que se intentaron: no hay índice, no un
            // índice corto. `consultadas` cuenta intentos, no éxitos.
            if fallidas > 0 && fallidas >= consultadas {
                return "No se ha podido consultar el censo de aspirantes."
            }
            let leidas = consultadas - fallidas
            return "Índice parcial: \(leidas) de \(disponibles) convocatorias en curso."
        }
    }

    var coverage = IndexCoverage()

    struct Aspirante: Identifiable, Hashable {
        let studentId: String
        let name: String
        let plaza: String?
        let convocatoriaName: String
        let haConducido: Bool
        var id: String { studentId + "-" + convocatoriaName }

        /// Compara ignorando tildes y mayúsculas.
        ///
        /// Muñoz, Núñez, Pérez y Martínez cubren buena parte de un censo
        /// español, y en el teclado del móvil se escriben sin tilde. Sin este
        /// plegado, buscar «Munoz» respondía que nadie coincide.
        func matches(_ query: String) -> Bool {
            let needle = Self.fold(query)
            guard !needle.isEmpty else { return true }
            return Self.fold(name).contains(needle)
                || Self.fold(plaza ?? "").contains(needle)
        }

        private static func fold(_ value: String) -> String {
            value
                .trimmingCharacters(in: .whitespaces)
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
        }
    }

    /// La capa de red, por parámetro.
    ///
    /// La misma costura que el resto de los modelos de vista: sin ella, la
    /// carga de este panel —que agrega dos peticiones en paralelo, indexa
    /// rankings con tope y acumula fallos parciales— no se podía ejercitar
    /// contra el doble de pruebas, y era la superficie con más lógica del área
    /// del instructor sin una sola prueba de comportamiento.
    private let api: TrainingAPI

    init(api: TrainingAPI = APIClient.shared) {
        self.api = api
    }

    /// Cuántas convocatorias se consultan para armar la lista.
    ///
    /// El endpoint de ranking va a 30 peticiones por minuto y esta pantalla se
    /// refresca al tirar hacia abajo. Con un tope bajo la función es útil sin
    /// convertir un panel en una ráfaga de peticiones.
    private static let maxConvocatoriasConsultadas = 3

    /// Convocatorias en curso.
    ///
    /// Usa la misma definición que la lista de convocatorias (`ConvocatoriaScope`)
    /// para que «en curso» no signifique dos cosas distintas en la misma app.
    /// La lista blanca anterior dejaba fuera `PREVIEW` y `CLOSING` —estados
    /// reales del backend—, así que una convocatoria en pleno cierre perdía a
    /// sus aspirantes del buscador justo cuando hacían falta.
    func activeConvocatorias(_ all: [ConvocatoriaSummaryDTO]) -> [ConvocatoriaSummaryDTO] {
        all.filter(ConvocatoriaScope.activas.matches)
    }

    func load(auth: AuthSession) async {
        state = .loading
        do {
            // Dashboard + convocatorias en paralelo: agregados del backend +
            // lista para la sección "Convocatorias activas".
            //
            // Ambas van dentro de la misma llamada autorizada: si el token
            // caduca, se refresca una vez y se reintentan las dos juntas.
            let (d, c) = try await auth.authorized { [api] token in
                async let dashboard = api.managerDashboard(accessToken: token)
                async let convs = api.convocatorias(accessToken: token)
                return try await (dashboard, convs)
            }
            state = .loaded(d, c)
            await loadAspirantes(convocatorias: c, auth: auth)
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Indexa a los inscritos de las convocatorias activas.
    ///
    /// Un fallo aquí **no** rompe el panel: es información complementaria, y
    /// perder los KPIs por no poder leer un ranking sería un mal negocio.
    private func loadAspirantes(
        convocatorias: [ConvocatoriaSummaryDTO],
        auth: AuthSession
    ) async {
        let activas = activeConvocatorias(convocatorias)
        let objetivo = activas.prefix(Self.maxConvocatoriasConsultadas)
        coverage = IndexCoverage(consultadas: objetivo.count, disponibles: activas.count)

        guard !objetivo.isEmpty else {
            aspirantes = []
            return
        }

        var acumulado: [Aspirante] = []
        for convocatoria in objetivo {
            do {
                let ranking = try await auth.authorized { [api] token in
                    try await api.ranking(
                        convocatoriaId: convocatoria.id,
                        accessToken: token
                    )
                }
                acumulado += ranking.entries.compactMap { entry in
                    guard let id = entry.candidate.id, !id.isEmpty else { return nil }
                    return Aspirante(
                        studentId: id,
                        name: entry.candidate.name ?? "—",
                        plaza: entry.candidate.plaza,
                        convocatoriaName: convocatoria.name,
                        haConducido: !entry.hasNotDriven
                    )
                }
            } catch {
                coverage.fallidas += 1
                AppLog.api.notice(
                    "No se pudo leer el ranking de una convocatoria para el índice de aspirantes: \(String(describing: error), privacy: .public)"
                )
            }
        }
        aspirantes = acumulado
    }

    /// Dispara sync on-demand. Backend rate-limit 3/min — si vuelve 429 lo
    /// mostramos como error sin reintentar.
    func triggerSync(auth: AuthSession) async {
        isSyncing = true
        syncResult = nil
        syncErrorMessage = nil
        defer { isSyncing = false }

        do {
            let result = try await auth.authorized { [api] token in
                try await api.webfletSync(accessToken: token)
            }
            syncResult = result
            // Tras sync exitoso, refrescamos el dashboard para que los KPIs
            // (intentos hoy, última sync) reflejen el cambio.
            await load(auth: auth)
        } catch APIError.rateLimited(let retryAfter) {
            if let retryAfter, retryAfter > 0 {
                syncErrorMessage = "Demasiadas peticiones. Inténtelo de nuevo en \(retryAfter) segundos."
            } else {
                syncErrorMessage = "Demasiadas peticiones. Espere un minuto antes de volver a intentarlo."
            }
        } catch let err as APIError {
            syncErrorMessage = err.userMessage
        } catch {
            syncErrorMessage = error.localizedDescription
        }
    }
}
