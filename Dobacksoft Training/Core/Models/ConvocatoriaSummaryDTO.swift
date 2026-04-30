import Foundation

struct ConvocatoriaSummaryDTO: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String?
    let status: String?
    let plazas: Int
    let totalCandidates: Int
    let closedAt: String?
    let updatedAt: String?
}

struct ConvocatoriasListDTO: Decodable, Sendable {
    let items: [ConvocatoriaSummaryDTO]
}
