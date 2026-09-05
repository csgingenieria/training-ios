import Foundation
import Observation
import os

@Observable
@MainActor
final class AuthSession {
    private let api: TrainingAPI

    /// `APIClient.shared` por defecto; los tests inyectan un doble.
    init(api: TrainingAPI = APIClient.shared) {
        self.api = api
    }

    var user: UserDTO?
    var accessToken: String?
    var refreshToken: String?
    var isRestoring: Bool = false
    var hasRestoredSession: Bool = false

    /// Refresco en curso, compartido por las llamadas que caducan a la vez.
    @ObservationIgnored private var refreshTask: Task<RefreshOutcome, Never>?

    var isAuthenticated: Bool { user != nil && accessToken != nil }

    func restoreFromKeychain() async {
        guard !isRestoring, !hasRestoredSession else { return }
        isRestoring = true
        defer {
            isRestoring = false
            hasRestoredSession = true
        }

        let access = loadToken(.accessToken)
        let refresh = loadToken(.refreshToken)

        guard access != nil || refresh != nil else { return }

        accessToken = access
        refreshToken = refresh

        do {
            try await restorePersistedSession(accessToken: access, refreshToken: refresh)
        } catch APIError.unauthenticated {
            await logout()
        } catch {
            // No invalidamos sesión por errores de transporte transitorios.
        }
    }

    func login(email: String, password: String) async throws {
        let response = try await api.login(email: email, password: password)
        persistTokens(accessToken: response.access_token, refreshToken: response.refresh_token)
        user = response.user
        hasRestoredSession = true
    }

    func logout() async {
        // Un fallo de Keychain no puede impedir cerrar sesión: el estado en
        // memoria se limpia igual y el token que quede en el almacén ya no se
        // usa. Se registra para que no pase inadvertido.
        do {
            try TokenStore.clearAll()
        } catch {
            AppLog.keychain.error("No se pudieron borrar los tokens: \(String(describing: error), privacy: .public)")
        }
        user = nil
        accessToken = nil
        refreshToken = nil
        hasRestoredSession = true
    }

    // MARK: - Llamadas autenticadas

    /// Ejecuta una llamada a la API con el token vigente y, si el backend
    /// responde 401, refresca una sola vez y reintenta.
    ///
    /// Antes el refresco solo ocurría al arrancar la app. Como el access token
    /// dura una hora, una sesión que se pasaba de ese tiempo dejaba al usuario
    /// viendo «La sesión ha caducado» en cada pantalla, sin más salida que
    /// cerrar sesión a mano: ninguna pantalla trataba el 401.
    ///
    /// Se reintenta **una sola vez**. Si el segundo intento vuelve a dar 401, el
    /// refresh token tampoco vale y se cierra la sesión: insistir solo
    /// encadenaría llamadas condenadas a fallar.
    ///
    /// Un refresco en curso se comparte entre llamadas concurrentes, así que
    /// cinco pantallas que caducan a la vez producen un único `POST /auth/refresh`.
    func authorized<T: Sendable>(
        _ operation: (String) async throws -> T
    ) async throws -> T {
        guard let token = accessToken else {
            throw APIError.unauthenticated
        }

        do {
            return try await operation(token)
        } catch APIError.unauthenticated {
            AppLog.auth.info("401 recibido; intentando refrescar el token")
        }

        switch await refreshAccessToken() {
        case let .renewed(renewed):
            do {
                return try await operation(renewed)
            } catch APIError.unauthenticated {
                AppLog.auth.error("401 tras refrescar; se cierra la sesión")
                await logout()
                throw APIError.unauthenticated
            }

        case .rejected:
            // El backend ha dicho que el refresh token ya no vale. Aquí sí no
            // hay sesión que salvar.
            AppLog.auth.error("El refresh token fue rechazado; se cierra la sesión")
            await logout()
            throw APIError.unauthenticated

        case let .unavailable(error):
            // No se ha podido PREGUNTAR: red caída, servidor con un 5xx, tiempo
            // agotado. Cerrar sesión aquí echaría a un bombero por meterse en un
            // túnel. Se propaga el fallo real y la sesión se queda como estaba.
            AppLog.auth.notice("Refresco no disponible; se conserva la sesión")
            throw error
        }
    }

    /// Resultado de intentar renovar el access token.
    ///
    /// La distinción entre «rechazado» y «no disponible» es la que decide si se
    /// cierra la sesión. Colapsar ambos en un `nil` hacía que cualquier fallo de
    /// red se tratara como credencial revocada.
    private enum RefreshOutcome {
        case renewed(String)
        /// El backend rechazó el refresh token (401/403).
        case rejected
        /// No se pudo completar la pregunta. La sesión sigue siendo válida.
        case unavailable(Error)
    }

    /// Renueva el access token.
    ///
    /// Las llamadas concurrentes esperan al refresco ya en curso en lugar de
    /// lanzar el suyo.
    private func refreshAccessToken() async -> RefreshOutcome {
        if let inFlight = refreshTask {
            return await inFlight.value
        }

        guard let refreshToken else { return .rejected }

        let task = Task { [api] () -> RefreshOutcome in
            do {
                let response = try await api.refresh(refreshToken: refreshToken)
                return .renewed(response.access_token)
            } catch APIError.unauthenticated, APIError.forbidden {
                return .rejected
            } catch {
                AppLog.auth.error("Refresco no disponible: \(String(describing: error), privacy: .public)")
                return .unavailable(error)
            }
        }
        refreshTask = task
        defer { refreshTask = nil }

        let outcome = await task.value
        if case let .renewed(renewed) = outcome {
            persistTokens(accessToken: renewed, refreshToken: refreshToken)
        }
        return outcome
    }

    private func restorePersistedSession(
        accessToken: String?,
        refreshToken: String?
    ) async throws {
        if let accessToken {
            do {
                user = try await api.me(accessToken: accessToken)
                return
            } catch APIError.unauthenticated {
                // Intentamos refresh más abajo si existe refresh token.
            }
        }

        guard let refreshToken else {
            throw APIError.unauthenticated
        }

        let refreshResponse = try await api.refresh(refreshToken: refreshToken)
        persistTokens(accessToken: refreshResponse.access_token, refreshToken: refreshToken)
        user = try await api.me(accessToken: refreshResponse.access_token)
    }

    /// Guarda los tokens y actualiza el estado en memoria.
    ///
    /// Si el Keychain falla, la sesión sigue siendo válida en esta ejecución
    /// pero no sobrevivirá al reinicio. Degradar así es preferible a tumbar un
    /// login correcto; queda registrado para poder diagnosticarlo.
    private func persistTokens(accessToken: String, refreshToken: String) {
        do {
            try TokenStore.save(accessToken, for: .accessToken)
            try TokenStore.save(refreshToken, for: .refreshToken)
        } catch {
            AppLog.keychain.error("No se pudieron guardar los tokens; la sesión no persistirá: \(String(describing: error), privacy: .public)")
        }
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    /// Lee un token tratando el fallo de Keychain como ausencia, pero dejando
    /// constancia: sin esto, un almacén roto y un usuario sin sesión eran
    /// exactamente lo mismo para la app.
    private func loadToken(_ key: TokenStore.Key) -> String? {
        do {
            return try TokenStore.load(for: key)
        } catch {
            AppLog.keychain.error("No se pudo leer \(key.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Preview helper — NO usar en producción.
    static var previewAuthenticated: AuthSession {
        let session = AuthSession()
        session.accessToken = "preview"
        session.refreshToken = "preview"
        session.hasRestoredSession = true
        session.user = UserDTO(
            id: "preview-id",
            email: "preview@cmadrid.com",
            name: "Preview User",
            role: "ADMIN",
            organizationId: "org-preview",
            studentProfileId: nil
        )
        return session
    }
}
