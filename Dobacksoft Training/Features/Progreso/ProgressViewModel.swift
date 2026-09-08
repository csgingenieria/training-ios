import SwiftUI

/// El estado de la pantalla de progreso.
///
/// Nace con la disciplina que a `StandingViewModel` hubo que añadirle después:
/// un refresco que falla conserva lo que ya estaba en pantalla, `notFound` no
/// cuenta como dato, y la hora es la del DATO y no la del intento de
/// refrescarlo. Haberlo encontrado una vez sirve para no repetirlo.
@MainActor
@Observable
final class ProgressViewModel {
    enum State {
        case loading
        case loaded(ProgressDTO)
        /// Con el motivo: no estar inscrito es una respuesta legítima del
        /// backend, no un fallo, y no puede leerse como uno.
        case notFound(NotFoundReason)
        case error(String)
    }

    var state: State = .loading

    /// Refresco en curso SOBRE datos ya visibles.
    var isRefreshing = false

    /// El fallo del último refresco, cuando había datos que conservar.
    var refreshError: String?

    /// Cuándo se obtuvieron los datos que se están enseñando.
    var lastUpdated: Date?

    private let api: TrainingAPI
    private let now: @Sendable () -> Date

    init(api: TrainingAPI = APIClient.shared, now: @escaping @Sendable () -> Date = Date.init) {
        self.api = api
        self.now = now
    }

    func load(convocatoriaId: String?, auth: AuthSession) async {
        let teniaDatos: Bool
        if case .loaded = state { teniaDatos = true } else { teniaDatos = false }

        if teniaDatos { isRefreshing = true } else { state = .loading }
        defer { isRefreshing = false }

        // Una convocatoria en blanco es lo mismo que ninguna, y NO se reenvía:
        // `?conv_id=` vacío da 400 y, peor, el respaldo del backend contestaría
        // por otra convocatoria con aspecto de respuesta correcta.
        let id = convocatoriaId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let convocatoria = (id?.isEmpty == false) ? id : nil

        do {
            let progreso = try await auth.authorized { [api] token in
                try await api.progress(convocatoriaId: convocatoria, accessToken: token)
            }
            state = .loaded(progreso)
            refreshError = nil
            lastUpdated = now()
        } catch let err as APIError where err.notFoundReason != nil {
            state = .notFound(err.notFoundReason ?? .resourceMissing)
        } catch {
            let mensaje = (error as? APIError)?.userMessage ?? error.localizedDescription
            if teniaDatos {
                refreshError = "\(mensaje) Se muestra el último dato consultado."
            } else {
                state = .error(mensaje)
            }
        }
    }
}
