import Foundation

/// Standing de un alumno en una convocatoria (vista por MANAGER/ADMIN).
///
/// Similar a `StandingDTO` pero incluye `name` de la convocatoria (el manager
/// abre el perfil sin contexto de qué convocatoria es cada standing).
///
/// Sin `plazas` ni derivados de «línea de corte», igual que `StandingDTO`:
/// RGPD art. 22. Ver la nota de ese tipo antes de añadir campos aquí.
struct ProfileStandingDTO: Sendable, Identifiable, Hashable {
    let convocatoriaId: String
    let name: String
    let position: Int
    let totalCandidates: Int
    let score: Double
    let attemptsCompleted: Int
    let attemptsTotal: Int
    let status: String

    let requiredRoutes: [String]?
    let completedRequired: Int?
    let pendingRequired: Int?
    let scoreOfCompleted: Double?

    /// De qué está hecha la nota. Ver `GradeComposition`.
    var composition: GradeComposition? {
        guard let completedRequired, let pendingRequired else { return nil }
        return GradeComposition(
            requiredRoutes: requiredRoutes,
            completedRequired: completedRequired,
            pendingRequired: pendingRequired,
            scoreOfCompleted: scoreOfCompleted
        )
    }

    var id: String { convocatoriaId }
}

nonisolated extension ProfileStandingDTO: Decodable {}

/// Respuesta de `GET /api/v1/students/<id>/profile` (MANAGER/ADMIN).
///
/// IMPORTANTE: 404 (no 403) cuando el alumno no existe, es de otra org, o no
/// tiene rol STUDENT — defense in depth, no leak de existencia. Tratar como
/// `APIError.notFound` y mostrar "Alumno no encontrado".
///
/// IMPORTANTE: `attempts.count` NO es lo mismo que la suma de
/// `standings[*].attemptsCompleted`. El listado incluye intentos cerrados sin
/// score (no validables); el contador agregado del standing solo cuenta los
/// validables. NO mezclar en UI.
struct StudentProfileDTO: Sendable {
    let user: UserDTO
    let standings: [ProfileStandingDTO]
    let attempts: [AttemptSummaryDTO]
}

nonisolated extension StudentProfileDTO: Decodable {}
