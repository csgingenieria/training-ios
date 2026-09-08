import Testing
import Foundation

@testable import Dobacksoft_Training

/// Which required routes the candidate has not driven yet.
///
/// This is the question the official grade turns into money: the mark is the
/// mean of the best attempt per REQUIRED route, **counting 0 for the routes not
/// driven** (#845). A candidate who does not know which ones are missing cannot
/// act on the one thing that would move their mark most.
///
/// The client derives the NAMES by set difference. It does not derive the
/// grade, and it does not derive the count either — the backend sends
/// `pendingRequired`. The derivation is cross-checked against that count, and
/// when the two disagree the names are withheld: telling someone to go drive a
/// route they already drove is worse than telling them nothing.
struct RequiredRoutesTests {
    private func progress(
        required: [String]?,
        driven: [String?],
        completedRequired: Int? = nil,
        pendingRequired: Int? = nil
    ) -> ProgressDTO {
        ProgressDTO(
            candidate: nil, convocatoria: nil, activeEnrollments: [],
            score: 5.0, presented: true,
            requiredRoutes: required,
            completedRequired: completedRequired,
            pendingRequired: pendingRequired,
            scoreOfCompleted: nil, attempts: [],
            evolution: driven.map {
                ProgressEvolutionDTO(
                    routeCode: $0, label: nil, score: 5.0, previousScore: nil,
                    trend: nil, diffVsScore: nil, attemptId: "a-\($0 ?? "x")"
                )
            },
            bestRoute: nil, worstRoute: nil
        )
    }

    // MARK: - La resta de conjuntos

    @Test func theRoutesNotDrivenAreNamed() {
        let p = progress(required: ["1A", "2B", "3C"], driven: ["1A"], pendingRequired: 2)
        #expect(RequiredRoutes.pending(in: p) == ["2B", "3C"])
    }

    /// Order follows the convocatoria's own list, not the alphabet: it is the
    /// order the candidate sees everywhere else.
    @Test func theOrderIsTheConvocatoriasOwn() {
        let p = progress(required: ["3C", "1A", "2B"], driven: [], pendingRequired: 3)
        #expect(RequiredRoutes.pending(in: p) == ["3C", "1A", "2B"])
    }

    /// A route driven but ungraded still counts as driven. The candidate has
    /// nothing left to do there; what is missing is the data from the truck,
    /// and sending them out again would be wrong advice.
    @Test func aDrivenRouteWithoutAGradeIsStillDriven() {
        let p = progress(required: ["1A", "2B"], driven: ["1A"], pendingRequired: 1)
        #expect(RequiredRoutes.pending(in: p) == ["2B"])
    }

    @Test func nothingPendingIsAnEmptyList() {
        let p = progress(required: ["1A"], driven: ["1A"], pendingRequired: 0)
        #expect(RequiredRoutes.pending(in: p) == [])
    }

    /// Routes driven that are NOT required do not subtract from anything.
    @Test func drivingSomethingElseChangesNothing() {
        let p = progress(required: ["1A"], driven: ["9Z", "8Y"], pendingRequired: 1)
        #expect(RequiredRoutes.pending(in: p) == ["1A"])
    }

    // MARK: - Cuándo NO se nombran

    /// **The disagreement rule.** If the derived count differs from the
    /// backend's `pendingRequired`, the client is working from a different
    /// picture than the one the mark was computed with. It stays quiet rather
    /// than naming routes it may have wrong.
    @Test func namesAreWithheldWhenTheCountDisagrees() {
        let p = progress(required: ["1A", "2B", "3C"], driven: ["1A"], pendingRequired: 1)
        #expect(RequiredRoutes.pending(in: p) == nil, "dos derivados contra uno del backend")
    }

    /// Without the backend's count there is nothing to check against, so
    /// nothing is claimed. This is the honest reading of a missing field —
    /// the same rule the rest of the client follows.
    @Test func withoutTheBackendsCountNothingIsClaimed() {
        let p = progress(required: ["1A", "2B"], driven: ["1A"], pendingRequired: nil)
        #expect(RequiredRoutes.pending(in: p) == nil)
    }

    /// Without a required-route list the concept does not exist: the grade is
    /// then the global best and no route is pending.
    @Test func withoutRequiredRoutesNothingIsPending() {
        #expect(RequiredRoutes.pending(in: progress(required: nil, driven: [], pendingRequired: 0)) == nil)
        #expect(RequiredRoutes.pending(in: progress(required: [], driven: [], pendingRequired: 0)) == nil)
    }

    /// The control case: the agreement check must be able to FAIL, or the rule
    /// above is decoration. A correct derivation passes it.
    @Test func theAgreementCheckAcceptsACorrectDerivation() {
        let p = progress(required: ["1A", "2B"], driven: ["1A"], pendingRequired: 1)
        #expect(RequiredRoutes.pending(in: p) == ["2B"])
    }

    // MARK: - Cómo se cuenta

    /// A blank or missing route code in the evolution is not a route. It must
    /// not silently cancel out a pending one.
    @Test func aBlankRouteCodeIsNotARoute() {
        let p = progress(required: ["1A"], driven: [nil, "   "], pendingRequired: 1)
        #expect(RequiredRoutes.pending(in: p) == ["1A"])
    }

    /// Codes are matched case-insensitively and trimmed: «1a » and «1A» are
    /// the same route, and a whitespace difference must not send someone out
    /// to drive a route they already drove.
    @Test func codesMatchDespiteCaseAndPadding() {
        let p = progress(required: ["1A", "2B"], driven: [" 1a "], pendingRequired: 1)
        #expect(RequiredRoutes.pending(in: p) == ["2B"])
    }

    /// The same route driven twice is one route driven.
    @Test func drivingARouteTwiceIsStillOneRoute() {
        let p = progress(required: ["1A", "2B"], driven: ["1A", "1A"], pendingRequired: 1)
        #expect(RequiredRoutes.pending(in: p) == ["2B"])
    }

    // MARK: - Lo que se le dice

    /// The sentence names what the zero costs, because that is the reason to
    /// care. It must not scold and must not predict an outcome.
    @Test func theSentenceExplainsWhatTheZeroCosts() throws {
        let copy = try #require(RequiredRoutes.notice(for: ["2B", "3C"]))
        #expect(copy.contains("2B"))
        #expect(copy.contains("3C"))
        #expect(copy.contains("0"))

        for banned in ["apto", "plaza", "corte", "admit", "aprob", "suspens", "exclu"] {
            #expect(!copy.lowercased().contains(banned), "«\(banned)» aparece en: \(copy)")
        }
    }

    /// Singular and plural, because «1 recorridos» reads as a bug to the
    /// person the app is for.
    @Test func oneRouteIsSingular() throws {
        let one = try #require(RequiredRoutes.notice(for: ["2B"]))
        #expect(one.contains("El recorrido"))
        let two = try #require(RequiredRoutes.notice(for: ["2B", "3C"]))
        #expect(two.contains("Los recorridos"))
    }

    /// Nothing pending says nothing. An empty notice would put a permanent
    /// empty card on the screen.
    @Test func nothingPendingSaysNothing() {
        #expect(RequiredRoutes.notice(for: []) == nil)
    }
}
