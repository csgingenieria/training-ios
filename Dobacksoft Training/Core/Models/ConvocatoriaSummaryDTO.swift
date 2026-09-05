import Foundation

/// Resumen de una convocatoria.
///
/// Sin `plazas`: el sistema no gestiona cupos. El backend todavía lo envía como
/// espejo de `totalCandidates` por compatibilidad y aquí se descarta.
struct ConvocatoriaSummaryDTO: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String?
    let status: String?
    let totalCandidates: Int
    let closedAt: String?
    let updatedAt: String?
}

nonisolated extension ConvocatoriaSummaryDTO: Decodable {}

struct ConvocatoriasListDTO: Sendable {
    let items: [ConvocatoriaSummaryDTO]
}

nonisolated extension ConvocatoriasListDTO: Decodable {}
