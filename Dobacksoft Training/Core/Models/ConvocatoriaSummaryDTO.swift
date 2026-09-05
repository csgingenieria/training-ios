import Foundation

struct ConvocatoriaSummaryDTO: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String?
    let status: String?
    let plazas: Int
    let totalCandidates: Int
    let closedAt: String?
    let updatedAt: String?
}

nonisolated extension ConvocatoriaSummaryDTO: Decodable {}

struct ConvocatoriasListDTO: Sendable {
    let items: [ConvocatoriaSummaryDTO]
}

nonisolated extension ConvocatoriasListDTO: Decodable {}
