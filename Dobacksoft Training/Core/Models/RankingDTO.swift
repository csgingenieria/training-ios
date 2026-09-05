import Foundation

struct RankingCandidateDTO: Hashable, Sendable {
    let id: String?
    let name: String?
    let plaza: String?
}

nonisolated extension RankingCandidateDTO: Decodable {}

struct RankingEntryDTO: Identifiable, Hashable, Sendable {
    let position: Int
    let candidate: RankingCandidateDTO
    let score: Double?
    let attemptsCompleted: Int
    let attemptsTotal: Int
    let attemptId: String?

    var id: String { (candidate.id ?? "anon") + "-\(position)" }
}

nonisolated extension RankingEntryDTO: Decodable {}

struct RankingResponseDTO: Sendable {
    let convocatoria: ConvocatoriaSummaryDTO
    let entries: [RankingEntryDTO]
}

nonisolated extension RankingResponseDTO: Decodable {}
