import Foundation

/// Respuesta de `GET /api/v1/me/dashboard` (MANAGER/ADMIN).
///
/// Notas de semántica documentadas por el backend (NO inventar):
/// - `attemptsToday` / `attemptsThisWeek`: corte de día/semana en Europe/Madrid
///   (no UTC). Excluye sesiones de calibración y attempts sintéticos.
/// - `lastWebfleetSyncAt`: MAX(Attempt.webfleetSyncedAt) de la org. NO es un
///   timestamp global "última sync de flota" — es proxy honesto. `nil` si
///   ningún attempt fue sincronizado todavía.
/// - `convocatoriasWithLowQuality`: convocatorias OPEN donde >25% de sus
///   intentos cerrados tienen `dataQuality == LOW`.
/// - `totalParticipants`: inscritos no invalidados en convocatorias OPEN.
///   Distinto de `totalCandidates`, que cuenta solo inscripciones ACTIVE.
///
/// `totalPlazas` ya no viene. El espejo de compatibilidad se retiró en el
/// backend y se verificó campo por campo contra staging el 2026-09-07: la
/// respuesta trae exactamente activeConvocatorias, totalCandidates,
/// totalParticipants, attemptsToday, attemptsThisWeek, lastWebfleetSyncAt y
/// convocatoriasWithLowQuality. El sistema no gestiona cupos.
struct ManagerDashboardDTO: Sendable {
    let activeConvocatorias: Int
    let totalCandidates: Int
    let totalParticipants: Int
    let attemptsToday: Int
    let attemptsThisWeek: Int
    let lastWebfleetSyncAt: String?
    let convocatoriasWithLowQuality: Int
}

nonisolated extension ManagerDashboardDTO: Decodable {}
