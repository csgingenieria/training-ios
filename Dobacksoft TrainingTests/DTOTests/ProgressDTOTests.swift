import Testing
import Foundation

@testable import Dobacksoft_Training

/// `GET /api/v1/me/progress`, read from `mobile_api/services.py` and
/// `schemas.py` on `origin/main` — the endpoint exists, so this is the real
/// contract and not a reading of the request document.
///
/// The two ⚠ the backend flags itself are the two things worth testing here,
/// because both are places where a plausible client would be wrong:
/// `diffVsScore` is measured against the OFFICIAL grade and not against a best
/// attempt, and `bestRoute`/`worstRoute` name a ROUTE by its last lap, which
/// can disagree with the attempt carrying `isCurrentBest` without either being
/// wrong.
struct ProgressDTOTests {
    private func decode(_ json: String) throws -> ProgressDTO {
        try JSONDecoder().decode(ProgressDTO.self, from: Data(json.utf8))
    }

    private let completo = #"""
    {
      "candidate": {"id": "s-1", "name": "Aspirante", "plaza": "118"},
      "convocatoria": {"id": "c-1", "name": "Oposición 2026", "closedAt": null},
      "activeEnrollments": [{"convocatoriaId": "c-1", "name": "Oposición 2026"}],
      "score": 6.0,
      "presented": true,
      "requiredRoutes": ["1A", "1B", "2A1"],
      "completedRequired": 2,
      "pendingRequired": 1,
      "scoreOfCompleted": 9.0,
      "attempts": [],
      "evolution": [
        {"routeCode": "1A", "label": "1A", "score": 10.0, "previousScore": null,
         "trend": "primer", "diffVsScore": 4.0, "attemptId": "a-1"},
        {"routeCode": "1B", "label": "1B", "score": 8.0, "previousScore": 9.0,
         "trend": "bajando", "diffVsScore": 2.0, "attemptId": "a-2"}
      ],
      "bestRoute": {"routeCode": "1A", "label": "1A", "score": 10.0, "attemptId": "a-1"},
      "worstRoute": {"routeCode": "1B", "label": "1B", "score": 8.0, "attemptId": "a-2"}
    }
    """#

    @Test func theWholeAnswerDecodes() throws {
        let p = try decode(completo)

        #expect(p.score == 6.0)
        #expect(p.presented == true)
        #expect(p.composition?.requiredRoutes == ["1A", "1B", "2A1"])
        #expect(p.composition?.completedRequired == 2)
        #expect(p.evolution.count == 2)
        #expect(p.bestRoute?.routeCode == "1A")
        #expect(p.convocatoria?.closedAt == nil)
    }

    // MARK: - presented, que no se puede deducir de score

    /// `canonical_nota` returns `0.0` both for a real zero and for «nothing
    /// yet», so `presented` is the only thing that tells them apart. Writing
    /// «0,0» to someone nobody has graded is the defect this field prevents.
    @Test func aZeroWithoutPresentingIsNotAGrade() throws {
        let sinCalificar = try decode(root(score: "0.0", presented: "false"))
        let ceroReal = try decode(root(score: "0.0", presented: "true"))

        #expect(sinCalificar.displayScore == nil, "no hay nota que enseñar")
        #expect(ceroReal.displayScore == 0.0, "un cero calificado es una nota")
    }

    // MARK: - Los dos ⚠ del backend

    /// The name says it: the difference is against the candidate's OFFICIAL
    /// grade, which with required routes is an average counting zeros — not
    /// against their best attempt. `1A` scores 10,0 against an official 6,0 and
    /// marks +4,0 on the very route where their best attempt sits.
    @Test func theDifferenceIsAgainstTheOfficialGradeNotTheBestAttempt() throws {
        let p = try decode(completo)
        let unoA = try #require(p.evolution.first { $0.routeCode == "1A" })

        #expect(unoA.diffVsScore == 4.0)
        #expect(unoA.score == 10.0)
        #expect(p.score == 6.0, "10,0 − 6,0 = +4,0: el sustraendo es la nota oficial")
    }

    /// `bestRoute` names the ROUTE whose LAST lap scored highest. A candidate
    /// who drove 10,0 and then 6,0 on one route has that route as `worstRoute`
    /// while the 10,0 still carries `isCurrentBest` in the list. Both are true
    /// and answer different questions.
    @Test func theBestRouteIsAboutTheLastLapNotTheBestAttempt() throws {
        let json = #"""
        {"score": 8.0, "presented": true, "evolution": [
           {"routeCode": "1A", "label": "1A", "score": 6.0, "previousScore": 10.0,
            "trend": "bajando", "diffVsScore": -2.0, "attemptId": "a-ultimo"}],
         "worstRoute": {"routeCode": "1A", "label": "1A", "score": 6.0, "attemptId": "a-ultimo"}}
        """#

        let p = try decode(json)

        #expect(p.worstRoute?.attemptId == "a-ultimo")
        #expect(p.worstRoute?.score == 6.0, "la última vuelta, no la mejor")
        #expect(p.evolution.first?.previousScore == 10.0, "el 10 sigue ahí, en su sitio")
    }

    /// With one graded route the two are the SAME, and saying it twice informs
    /// of nothing. The API sends both because the datum is true; not painting
    /// them is the client's decision, so the client has to be able to tell.
    @Test func withASingleRouteBothExtremesAreTheSameAndTheBlockIsNotWorthPainting() throws {
        let json = #"""
        {"score": 7.0, "presented": true, "evolution": [],
         "bestRoute":  {"routeCode": "1A", "label": "1A", "score": 7.0, "attemptId": "a-1"},
         "worstRoute": {"routeCode": "1A", "label": "1A", "score": 7.0, "attemptId": "a-1"}}
        """#

        let p = try decode(json)

        #expect(p.extremesAreWorthShowing == false)
    }

    @Test func withTwoDifferentRoutesTheBlockDoesInform() throws {
        #expect(try decode(completo).extremesAreWorthShowing)
    }

    @Test func withNoGradedRouteThereAreNoExtremes() throws {
        let p = try decode(#"{"score": 0.0, "presented": false, "evolution": []}"#)

        #expect(p.bestRoute == nil)
        #expect(p.extremesAreWorthShowing == false)
    }

    // MARK: - trend

    @Test func theFourTrendsAreUnderstood() throws {
        for (raw, esperado) in [("subiendo", ProgressTrend.subiendo), ("bajando", .bajando),
                                ("estable", .estable), ("primer", .primer)] {
            let p = try decode(evolucion(trend: raw))
            #expect(p.evolution.first?.trend == esperado)
        }
    }

    /// `primer` is not «no data»: it is the first lap of that route, and the
    /// screen has to say so rather than leave a gap.
    @Test func theFirstLapIsNotAMissingValue() throws {
        let p = try decode(evolucion(trend: "primer"))
        let entrada = try #require(p.evolution.first)

        #expect(entrada.trend == .primer)
        #expect(entrada.trend?.isFirstLap == true)
        #expect(entrada.previousScore == nil, "no hay vuelta anterior contra la que comparar")
    }

    @Test func anUnknownTrendIsNotInvented() throws {
        #expect(try decode(evolucion(trend: "haciendo_el_pino")).evolution.first?.trend == nil)
    }

    // MARK: - Helpers

    private func root(score: String, presented: String) -> String {
        #"{"score": \#(score), "presented": \#(presented), "evolution": []}"#
    }

    private func evolucion(trend: String) -> String {
        #"""
        {"score": 7.0, "presented": true, "evolution": [
          {"routeCode": "1A", "label": "1A", "score": 7.0, "previousScore": null,
           "trend": "\#(trend)", "diffVsScore": 0.0, "attemptId": "a-1"}]}
        """#
    }
}
