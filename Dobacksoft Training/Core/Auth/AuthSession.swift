import Foundation
import Observation
import os

@Observable
@MainActor
final class AuthSession {
    private let api: TrainingAPI

    /// `APIClient.shared` por defecto; los tests inyectan un doble.
    /// Dónde vive la caché de arranque sin cobertura. Se inyecta para poder
    /// probar que cerrar sesión la borra de verdad.
    private let lastGood: LastGoodStore

    init(api: TrainingAPI = APIClient.shared, lastGood: LastGoodStore = .appContainer) {
        self.api = api
        self.lastGood = lastGood
    }

    var user: UserDTO?
    var accessToken: String?
    var refreshToken: String?
    var isRestoring: Bool = false
    var hasRestoredSession: Bool = false

    /// Por qué se cerró la última sesión, o `nil` si no se ha cerrado ninguna.
    ///
    /// Las transiciones de estado ya eran correctas; lo que no hacían era decir
    /// nada. Un refresh token rechazado y un «Cerrar sesión» dejaban a la
    /// persona en el mismo formulario vacío, y necesitan mensajes opuestos: uno
    /// explica que hubo que pedir la contraseña otra vez, el otro no tiene nada
    /// que explicar.
    var logoutReason: LogoutReason?

    /// El fallo de red que impidió restaurar la sesión, con los tokens intactos.
    ///
    /// Distinto de `logoutReason`: aquí **no** se ha cerrado nada. Las
    /// credenciales siguen en el Keychain y el problema es que no se ha podido
    /// preguntar. Sin este dato, `RootView` no puede distinguir «sin conexión,
    /// su sesión sigue activa» de «no ha iniciado sesión», y enseña el
    /// formulario de acceso a alguien cuya sesión está perfectamente viva —
    /// donde teclear la contraseña también falla, que es lo que se lee como
    /// «mi cuenta está rota».
    var restoreFailure: APIError?

    /// Hay credenciales guardadas y un fallo que reintentar.
    var canRetryRestore: Bool { restoreFailure != nil && refreshToken != nil }

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

        #if DEBUG
        // La sesión vive en el Keychain y sobrevive entre ejecuciones, así que
        // un recorrido automatizado arrancaba con la sesión de la ejecución
        // ANTERIOR: pedía entrar como aspirante, se encontraba dentro como
        // instructor, no hallaba su pantalla y se saltaba en verde sin haber
        // comprobado nada. Este argumento existe para que el test pueda exigir
        // una sesión limpia; solo en DEBUG, y nunca lo pasa la app.
        if CommandLine.arguments.contains("-uitest-reset-session") {
            try? TokenStore.clearAll()
            return
        }
        #endif

        let access = loadToken(.accessToken)
        let refresh = loadToken(.refreshToken)

        guard access != nil || refresh != nil else { return }

        accessToken = access
        refreshToken = refresh

        do {
            try await restorePersistedSession(accessToken: access, refreshToken: refresh)
            restoreFailure = nil
        } catch APIError.unauthenticated {
            await logout(reason: .sessionExpired)
        } catch {
            // No invalidamos sesión por errores de transporte transitorios,
            // pero tampoco los enterramos: este catch era silencioso y dejaba
            // al aspirante en el formulario de acceso, sin mensaje, con su
            // sesión entera guardada.
            restoreFailure = error as? APIError ?? .transport(error)
        }
    }

    /// Vuelve a intentar la restauración tras un fallo de red.
    ///
    /// `restoreFromKeychain()` se autolimita a una ejecución para que una
    /// jerarquía de vistas que aparece dos veces no dispare dos `GET /me`. Ese
    /// mismo candado dejaba sin salida a quien arrancó la app sin cobertura: no
    /// había nada a lo que pudiera llamar un botón «Reintentar».
    func retryRestore() async {
        guard canRetryRestore else { return }
        hasRestoredSession = false
        restoreFailure = nil
        await restoreFromKeychain()
    }

    func login(email: String, password: String) async throws {
        let response = try await api.login(email: email, password: password)
        persistTokens(accessToken: response.access_token, refreshToken: response.refresh_token)
        user = response.user
        hasRestoredSession = true
        // La sesión funciona: cualquier aviso del intento anterior ya es falso.
        logoutReason = nil
        restoreFailure = nil

        // Purgar antes de nada: dos aspirantes pueden compartir dispositivo, y
        // el segundo no puede heredar la posición del primero.
        SnapshotPublisher.shared.clear()
        SnapshotPublisher.shared.publish(
            response.user.isStudent ? .sinDatosAun : .sinPosicionPropia
        )
    }

    /// Cierra la sesión declarando por qué.
    ///
    /// El motivo no tiene valor por defecto a propósito: cada sitio que cierra
    /// una sesión sabe si fue una decisión de la persona o un rechazo del
    /// backend, y el compilador es el único sitio donde esa distinción no se
    /// puede olvidar al añadir una salida nueva.
    func logout(reason: LogoutReason) async {
        // Un fallo de Keychain no puede impedir cerrar sesión: el estado en
        // memoria se limpia igual y el token que quede en el almacén ya no se
        // usa. Se registra para que no pase inadvertido.
        do {
            try TokenStore.clearAll()
        } catch {
            AppLog.keychain.error("No se pudieron borrar los tokens: \(String(describing: error), privacy: .public)")
        }
        // Sin esto, el widget de quien acaba de salir seguiría enseñando su
        // puesto en la pantalla de inicio.
        SnapshotPublisher.shared.clear()

        // Y sin esto, la caché de arranque sin cobertura sobreviviría a la
        // sesión. Va ANTES de poner `user` a nil, que es de donde sale el
        // identificador con el que está guardada: al revés no habría a quién
        // borrar, y el defecto sería silencioso — nadie ve una caché que no se
        // borra hasta que la lee otra persona en el mismo dispositivo.
        if let userId = user?.id {
            lastGood.clear(userId: userId)
        }

        user = nil
        accessToken = nil
        refreshToken = nil
        hasRestoredSession = true
        logoutReason = reason
        // Ya no hay tokens: no queda nada que reintentar, y un aviso de «sin
        // conexión» encima del de «sesión caducada» solo confunde.
        restoreFailure = nil
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
                await logout(reason: .sessionExpired)
                throw APIError.unauthenticated
            }

        case .rejected:
            // El backend ha dicho que el refresh token ya no vale. Aquí sí no
            // hay sesión que salvar.
            AppLog.auth.error("El refresh token fue rechazado; se cierra la sesión")
            await logout(reason: .sessionExpired)
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
