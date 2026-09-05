import Testing
import Foundation

@testable import Dobacksoft_Training

struct RankingDTOTests {
    @Test func decodeRanking() throws {
        let dto: RankingResponseDTO = try JSONFixture.decode("ranking")
        #expect(dto.entries.count == 3)
        #expect(dto.convocatoria.id == "conv-001")
    }

    @Test func decodeRankingEntry() throws {
        let dto: RankingResponseDTO = try JSONFixture.decode("ranking")
        let first = dto.entries[0]
        #expect(first.position == 1)
        #expect(first.candidate.name == "María García")
        #expect(first.score == 9.2)
        #expect(first.attemptsCompleted == 5)
        #expect(first.attemptsTotal == 5)
    }

    @Test func rankingEntryIdentifiable() throws {
        let dto: RankingResponseDTO = try JSONFixture.decode("ranking")
        let ids = Set(dto.entries.map { $0.id })
        #expect(ids.count == 3)
    }
}
