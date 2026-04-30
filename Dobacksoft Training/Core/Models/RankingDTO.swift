import Foundation

struct RankingCandidateDTO: Decodable, Hashable, Sendable {
    let id: String?
    let name: String?
    let plaza: String?
}

struct RankingEntryDTO: Decodable, Identifiable, Hashable, Sendable {
    let position: Int
    let candidate: RankingCandidateDTO
    let score: Double?
    let attemptsCompleted: Int
    let attemptsTotal: Int

    var id: String { (candidate.id ?? "anon") + "-\(position)" }
}

struct RankingResponseDTO: Decodable, Sendable {
    let convocatoria: ConvocatoriaSummaryDTO
    let entries: [RankingEntryDTO]
}
