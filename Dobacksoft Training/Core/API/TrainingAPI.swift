import Foundation

/// Superficie de la API móvil v1 que consume la app.
///
/// Existe para poder sustituir la capa de red en pruebas. `APIClient` es un
/// `actor` concreto con `static let shared`, así que sin esta abstracción no
/// había forma de ejercitar `login()`, la restauración de sesión ni el refresco
/// tras un 401: los tests que lo intentaban acababan comprobando asignaciones
/// que ellos mismos hacían.
///
/// Refleja el contrato real de `app/blueprints/mobile_api/` en el repo
/// `training`. No inventar métodos que el backend no expone.
protocol TrainingAPI: Sendable {
    // Públicos
    func health() async throws -> HealthDTO
    func login(email: String, password: String) async throws -> AuthLoginResponseDTO
    func refresh(refreshToken: String) async throws -> RefreshResponseDTO

    // Sesión
    func me(accessToken: String) async throws -> UserDTO

    // Alumno
    func myConvocatorias(accessToken: String) async throws -> [ConvocatoriaSummaryDTO]
    func standing(convocatoriaId: String, accessToken: String) async throws -> StandingDTO

    /// Cómo va el aspirante. `conv_id` opcional; **nunca vacío**: el backend
    /// responde 400 porque una cadena vacía caería a su respaldo y
    /// contestaría por otra convocatoria con aspecto de respuesta correcta.
    func progress(convocatoriaId: String?, accessToken: String) async throws -> ProgressDTO

    /// Con qué tarjeta va a conducir. Solo texto: el cliente no lee el chip.
    func myCard(accessToken: String) async throws -> CardDTO

    /// La traza de la vuelta. `track` es la buena; `points` el respaldo.
    func attemptGps(id: String, accessToken: String) async throws -> GpsPayloadDTO

    /// El PIN de tablet del propio aspirante.
    ///
    /// ⚠ El backend AUDITA cada consulta, también cuando el PIN no se puede
    /// mostrar. No llamarlo de fondo ni en un refresco automático: se llama
    /// cuando la persona entra a verlo.
    func myPin(accessToken: String) async throws -> PinDTO

    /// Cambia la contraseña del usuario autenticado.
    ///
    /// Única escritura de cuenta del API móvil y primer `PATCH` del
    /// blueprint: excepción puntual y enumerada a D-API-001.
    func changePassword(
        current: String,
        new: String,
        confirm: String,
        accessToken: String
    ) async throws
    func myAttempts(convocatoriaId: String, accessToken: String) async throws -> [AttemptSummaryDTO]

    // Instructor / administración
    func convocatorias(accessToken: String) async throws -> [ConvocatoriaSummaryDTO]
    func convocatoriaDetail(id: String, accessToken: String) async throws -> ConvocatoriaSummaryDTO
    func ranking(convocatoriaId: String, accessToken: String) async throws -> RankingResponseDTO
    func matrix(convocatoriaId: String, accessToken: String) async throws -> MatrixResponseDTO
    func attempt(id: String, accessToken: String) async throws -> AttemptDetailDTO
    func managerDashboard(accessToken: String) async throws -> ManagerDashboardDTO
    func studentProfile(studentId: String, accessToken: String) async throws -> StudentProfileDTO

    // Webfleet
    func webfletAlerts(accessToken: String) async throws -> WebfletAlertsResponseDTO
    func webfletSync(accessToken: String) async throws -> SyncResultDTO
}

extension APIClient: TrainingAPI {}
