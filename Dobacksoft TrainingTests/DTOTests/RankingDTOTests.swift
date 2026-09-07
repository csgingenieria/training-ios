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

/// The ranking sends each entry's grade composition, and the DTO used to throw
/// it away. The instructor read «4,75» with nothing to explain the number.
struct RankingCompositionTests {
    /// The exact shape the staging server returns for the leading candidate of
    /// a real convocatoria: five required routes driven between 8,5 and 10, an
    /// average of 9,5 — and an official grade of 4,75, because the five the
    /// panel has not made driveable count zero.
    private func leader() throws -> RankingEntryDTO {
        let json = Data("""
        {
          "attemptId": "a1",
          "attemptsCompleted": 5,
          "attemptsTotal": 5,
          "candidate": {"id": "c1", "name": "Nombre Aspirante", "plaza": "011"},
          "completedRequired": 5,
          "pendingRequired": 5,
          "position": 1,
          "presented": true,
          "requiredRoutes": ["1A","1B","2A1","2A2","2A3","2B1","2B2","2B3","3A","3B"],
          "score": 4.75,
          "scoreOfCompleted": 9.5,
          "tied": false
        }
        """.utf8)
        return try JSONDecoder().decode(RankingEntryDTO.self, from: json)
    }

    @Test func compositionSurvivesDecoding() throws {
        let composition = try #require(try leader().composition)

        #expect(composition.totalRequired == 10)
        #expect(composition.completedRequired == 5)
        #expect(composition.pendingRequired == 5)
        #expect(composition.scoreOfCompleted == 9.5)
        #expect(composition.hasPendingRoutes)
    }

    /// The arithmetic that makes the row confusing without an explanation.
    @Test func theGradeIsTheAverageOverEveryRequiredRoute() throws {
        let entry = try leader()
        let composition = try #require(entry.composition)
        let average = try #require(composition.scoreOfCompleted)

        let official = average * Double(composition.completedRequired) / Double(composition.totalRequired)
        #expect(abs(official - (entry.score ?? 0)) < 0.01)
    }

    /// Someone enrolled who has not driven has no grade to compose. «0 de 10»
    /// beside an empty score reads as a measured zero.
    @Test func notDrivenComposesNothing() throws {
        let json = Data("""
        {
          "attemptId": null, "attemptsCompleted": 0, "attemptsTotal": 0,
          "candidate": {"id": "c2", "name": "Otro Aspirante", "plaza": "012"},
          "completedRequired": 0, "pendingRequired": 10, "position": null,
          "presented": false,
          "requiredRoutes": ["1A","1B","2A1","2A2","2A3","2B1","2B2","2B3","3A","3B"],
          "score": 0.0, "scoreOfCompleted": null, "tied": false
        }
        """.utf8)

        let entry = try JSONDecoder().decode(RankingEntryDTO.self, from: json)

        #expect(entry.hasNotDriven)
        #expect(entry.displayScore == nil)
        #expect(entry.composition == nil)
    }

    /// A payload from before the contract carried these fields must still
    /// decode — the app ships to devices that outlive a backend release.
    @Test func olderPayloadsStillDecode() throws {
        let json = Data("""
        {
          "attemptId": "a2", "attemptsCompleted": 1, "attemptsTotal": 1,
          "candidate": {"id": "c3", "name": "Tercero", "plaza": null},
          "position": 1, "score": 8.5
        }
        """.utf8)

        let entry = try JSONDecoder().decode(RankingEntryDTO.self, from: json)

        #expect(entry.composition == nil)
        #expect(entry.displayScore == 8.5)
    }
}
