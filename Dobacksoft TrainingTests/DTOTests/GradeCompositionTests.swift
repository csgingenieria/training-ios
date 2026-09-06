import Testing
import Foundation

@testable import Dobacksoft_Training

/// What the official grade is made of.
///
/// The real production case that motivated this: a candidate with 4.75 as their
/// official grade and 9.50 across everything they actually drove — five
/// required routes done between 8.5 and 10, plus five the panel never made
/// drivable. Reading "4.75" alone, that person concludes they drive badly.
struct GradeCompositionTests {
    private func composition(
        required: [String]? = ["A", "B", "C", "D"],
        completed: Int = 2,
        pending: Int = 2,
        conducted: Double? = 9.0
    ) -> GradeComposition {
        .init(
            requiredRoutes: required,
            completedRequired: completed,
            pendingRequired: pending,
            scoreOfCompleted: conducted
        )
    }

    /// `null` in `requiredRoutes` means the convocatoria requires no specific
    /// routes and the grade is the best single attempt. An empty list would
    /// mean it requires zero, which is a different claim.
    @Test func nullRequiredRoutesMeansGlobalBest() {
        #expect(composition(required: nil).isGlobalBest)
        #expect(!composition(required: []).isGlobalBest)
    }

    /// With no required set there is nothing to explain: the grade is not a
    /// mean with zeros in it.
    @Test func globalBestExplainsNothing() {
        #expect(composition(required: nil, pending: 0).explanation == nil)
        #expect(composition(required: nil).progress == nil)
    }

    @Test func pendingRoutesAreExplained() throws {
        let text = try #require(composition(completed: 5, pending: 5).explanation)
        #expect(text.contains("5 recorridos"))
        #expect(text.contains("cero"))
    }

    @Test func singlePendingRouteReadsInSingular() throws {
        let text = try #require(composition(completed: 3, pending: 1).explanation)
        #expect(text.contains("1 recorrido aún"))
        #expect(!text.contains("recorridos"))
    }

    /// Everything driven: no zeros inside, nothing to warn about.
    @Test func nothingPendingExplainsNothing() {
        #expect(composition(completed: 4, pending: 0).explanation == nil)
    }

    /// Wording must describe, not prescribe. "Le faltan" implies a duty and a
    /// verdict; "incluye N sin conducir" is a fact.
    @Test func wordingStaysWithinArticle22() throws {
        let text = try #require(composition(completed: 1, pending: 3).explanation).lowercased()
        for banned in ["falta", "apto", "suspens", "aprob", "plaza", "corte", "debe"] {
            #expect(!text.contains(banned), "«\(banned)» aparece en: \(text)")
        }
    }

    @Test func progressReflectsRequiredRoutes() {
        let progress = composition(required: ["A", "B", "C", "D"], completed: 1, pending: 3).progress
        #expect(progress == 0.25)
    }

    /// The whole point: the grade and the driving are different numbers.
    @Test func decodesTheRealProductionCase() throws {
        let dto: StandingDTO = try JSONFixture.decode("standing")
        let composition = try #require(dto.composition)

        #expect(composition.totalRequired == 10)
        #expect(composition.completedRequired == 5)
        #expect(composition.pendingRequired == 5)
        #expect(composition.scoreOfCompleted == 9.5)
        #expect(composition.hasPendingRoutes)
        #expect(composition.explanation != nil)
    }

    /// A response from before the contract grew must still decode. The app
    /// simply has nothing to explain.
    @Test func olderResponsesWithoutCompositionStillDecode() throws {
        let json = Data("""
        {
            "convocatoriaId": "c", "position": 3, "totalCandidates": 42,
            "score": 7.5, "attemptsCompleted": 3, "attemptsTotal": 5,
            "status": "ACTIVE"
        }
        """.utf8)

        let dto = try JSONDecoder().decode(StandingDTO.self, from: json)

        #expect(dto.position == 3)
        #expect(dto.composition == nil)
    }
}
