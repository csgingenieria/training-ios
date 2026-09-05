import Testing
import Foundation

@testable import Dobacksoft_Training

struct RankingDTOTests {
    @Test func decodeRanking() throws {
        let dto: RankingResponseDTO = try JSONFixture.decode("ranking")
        #expect(dto.entries.count == 4)
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

    /// The backend emits `position: null` for anyone enrolled who has not
    /// driven. A non-optional `Int` inside an array made the whole response
    /// undecodable, so one absentee cost the instructor the entire ranking.
    @Test func entryWithoutPositionDecodes() throws {
        let dto: RankingResponseDTO = try JSONFixture.decode("ranking")
        let absent = try #require(dto.entries.last)
        #expect(absent.position == nil)
        #expect(absent.candidate.name == "Sin conducir")
    }

    /// One absentee must not take the ranked entries down with it.
    @Test func rankedEntriesSurviveAnAbsentee() throws {
        let dto: RankingResponseDTO = try JSONFixture.decode("ranking")
        let ranked = dto.entries.filter { $0.position != nil }
        #expect(ranked.count == 3)
    }

    /// Not having driven is not a zero: a zero claims something was measured
    /// and came out badly. That is a false statement about a person sitting a
    /// public examination.
    @Test func absenteeShowsNoScore() throws {
        let dto: RankingResponseDTO = try JSONFixture.decode("ranking")
        let absent = try #require(dto.entries.last)
        #expect(absent.displayScore == nil)
    }

    @Test func rankedEntryKeepsItsScore() throws {
        let dto: RankingResponseDTO = try JSONFixture.decode("ranking")
        #expect(dto.entries[0].displayScore == 9.2)
    }

    @Test func rankingEntryIdentifiable() throws {
        let dto: RankingResponseDTO = try JSONFixture.decode("ranking")
        let ids = Set(dto.entries.map { $0.id })
        #expect(ids.count == dto.entries.count)
    }

    /// Absentees sort last, never as position zero.
    @Test func absenteesSortAfterRankedEntries() throws {
        let dto: RankingResponseDTO = try JSONFixture.decode("ranking")
        let sorted = RankingSortMode.position.apply(dto.entries)
        #expect(sorted.first?.position == 1)
        #expect(sorted.last?.position == nil)
    }
}
