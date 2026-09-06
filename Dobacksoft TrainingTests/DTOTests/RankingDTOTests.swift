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

/// The contract now states who has driven and who ties, instead of the app
/// inferring it from a missing position.
struct RankingPresentedTests {
    @Test func presentedFlagBeatsTheHeuristic() throws {
        let json = Data("""
        {
          "position": null, "candidate": {"id": "c", "name": "X", "plaza": "1"},
          "score": 0.0, "attemptsCompleted": 0, "attemptsTotal": 0,
          "presented": false, "tied": false
        }
        """.utf8)

        let entry = try JSONDecoder().decode(RankingEntryDTO.self, from: json)

        #expect(entry.hasNotDriven)
        #expect(entry.displayScore == nil)
    }

    /// The backend can report someone as presented while still computing their
    /// position. The explicit flag must win over the inference.
    @Test func presentedWithoutPositionIsStillPresented() throws {
        let json = Data("""
        {
          "position": null, "candidate": {"id": "c", "name": "X", "plaza": "1"},
          "score": 6.0, "attemptsCompleted": 2, "attemptsTotal": 3,
          "presented": true, "tied": false
        }
        """.utf8)

        let entry = try JSONDecoder().decode(RankingEntryDTO.self, from: json)

        #expect(!entry.hasNotDriven)
        #expect(entry.displayScore == 6.0)
    }

    /// Older responses without the flag fall back to the previous inference.
    @Test func absentFlagFallsBackToPosition() throws {
        let dto: RankingResponseDTO = try JSONFixture.decode("ranking")
        #expect(dto.entries.last?.hasNotDriven == true)
        #expect(dto.entries[0].hasNotDriven == false)
    }

    /// Competition numbering is 1, 2, 2, 4. Two rows sharing a number look like
    /// a bug unless the app says they are tied.
    @Test func tiesAreCarried() throws {
        let json = Data("""
        {
          "position": 2, "candidate": {"id": "c", "name": "X", "plaza": "1"},
          "score": 8.0, "attemptsCompleted": 3, "attemptsTotal": 3,
          "presented": true, "tied": true
        }
        """.utf8)

        let entry = try JSONDecoder().decode(RankingEntryDTO.self, from: json)
        #expect(entry.tied == true)
    }
}

/// Route naming and category, both nullable by contract.
struct AttemptRouteTests {
    private func route(name: String?, categoria: String?) -> AttemptRouteDTO {
        .init(id: "2A1", label: "2A1", name: name, categoria: categoria)
    }

    /// `label` is the raw code, so falling back to it beats showing nothing.
    @Test func displayNamePrefersTheReadableName() {
        #expect(route(name: "Parque → Hoyo", categoria: "EXAMEN").displayName == "Parque → Hoyo")
        #expect(route(name: nil, categoria: "EXAMEN").displayName == "2A1")
    }

    @Test func practiceRoutesAreIdentified() {
        #expect(route(name: "X", categoria: "PRACTICA").isPractice == true)
        #expect(route(name: "X", categoria: "EXAMEN").isPractice == false)
    }

    /// Attempts with no route exist in production, with a grade. Claiming they
    /// are exam routes would be inventing.
    @Test func absentCategoryClaimsNothing() {
        #expect(route(name: nil, categoria: nil).isPractice == nil)
        #expect(route(name: nil, categoria: "").isPractice == nil)
    }

    @Test func decodesFromTheFixture() throws {
        let dto: MyAttemptsListDTO = try JSONFixture.decode("my-attempts")
        #expect(dto.items.contains { $0.route?.isPractice == true })
        #expect(dto.items.contains { $0.route?.name != nil })
    }
}
