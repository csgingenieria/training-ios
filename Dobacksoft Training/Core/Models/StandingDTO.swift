import Foundation

/// Posición individual del STUDENT en una convocatoria.
///
/// El sistema **no gestiona plazas ni cupos** y **no emite veredicto**: calcula
/// una nota y una posición, y la admisión la decide CMadrid fuera del sistema
/// al cierre formal. Es el artículo 22 del RGPD, no una preferencia de diseño.
///
/// Por eso este DTO no expone `plazas` ni deriva ningún «estoy dentro»:
/// - El backend nunca envió `withinCutoff` (decisión `D-API-001`).
/// - `plazas` llega todavía como espejo de `totalCandidates` por compatibilidad
///   temporal, y se descarta al decodificar.
///
/// No volver a añadirlos. Un campo que no existe no se puede pintar por error.
struct StandingDTO: Sendable {
    let convocatoriaId: String
    let position: Int
    let totalCandidates: Int
    let score: Double
    let attemptsCompleted: Int
    let attemptsTotal: Int
    let status: String
}

nonisolated extension StandingDTO: Decodable {}
