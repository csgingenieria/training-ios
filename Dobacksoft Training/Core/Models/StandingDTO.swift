import Foundation

/// Posición individual del STUDENT en una convocatoria.
/// **No incluye `withinCutoff`** — decisión D-API-001 GDPR. Si querés mostrar
/// "estoy dentro" en la UI, calculá `position <= plazas` en cliente, y NO lo etiquetes
/// como APTO/NO APTO (es metadata operacional, no decisión legal).
struct StandingDTO: Decodable, Sendable {
    let convocatoriaId: String
    let position: Int
    let totalCandidates: Int
    let plazas: Int
    let score: Double
    let attemptsCompleted: Int
    let attemptsTotal: Int
    let status: String

    /// Heurística cliente — NO es decisión APTO/NO APTO.
    var isWithinAvailableSeats: Bool { position <= plazas }
}
