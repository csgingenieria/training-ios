import Testing
import Foundation

@testable import Dobacksoft_Training

/// What each route's row says under its name.
///
/// This is the only part of the progress screen with a decision in it, and the
/// decision is what NOT to say. Three traps, all of them things a plausible
/// implementation gets wrong:
///
/// - The first lap has no previous lap. «0,0 menos que la vuelta anterior» is
///   arithmetic on a value that does not exist.
/// - `diffVsScore` is measured against the OFFICIAL grade, so the row must not
///   word it as «respecto a tu mejor intento» — on the route holding their best
///   attempt that sentence is false by +4,0.
/// - A route with no grade is not a route with a zero.
struct ProgresoRowCopyTests {
    private func entrada(
        score: Double? = 8.0,
        previousScore: Double? = nil,
        trend: String? = "primer",
        diffVsScore: Double? = 0.0
    ) -> ProgressEvolutionDTO {
        ProgressEvolutionDTO(
            routeCode: "1A", label: "1A",
            score: score, previousScore: previousScore,
            trend: ProgressTrend(apiValue: trend),
            diffVsScore: diffVsScore, attemptId: "a-1"
        )
    }

    // MARK: - La primera vuelta

    /// No comparison, because there is nothing to compare against. Saying
    /// «igual que la anterior» would invent a lap that never happened.
    @Test func theFirstLapDoesNotCompareItselfToAnything() {
        let copy = ProgresoRowCopy.subtitle(for: entrada(trend: "primer"))

        #expect(copy.contains("Primera vuelta"))
        #expect(copy.contains("anterior") == false)
        #expect(copy.contains("0,0") == false, "no hay diferencia que enseñar")
    }

    // MARK: - La comparación contra la vuelta anterior

    @Test func aRiseIsSaidAgainstThePreviousLap() {
        let copy = ProgresoRowCopy.subtitle(for: entrada(score: 9.0, previousScore: 7.0, trend: "subiendo"))

        #expect(copy.contains("Mejora"))
        #expect(copy.contains("2,0"), "la diferencia contra la vuelta anterior: 9,0 − 7,0")
        #expect(copy.contains("anterior"))
    }

    @Test func aFallIsSaidWithoutDramatisingIt() {
        let copy = ProgresoRowCopy.subtitle(for: entrada(score: 6.0, previousScore: 10.0, trend: "bajando"))

        #expect(copy.contains("Baja"))
        #expect(copy.contains("4,0"))
        // Descriptivo: la vuelta bajó, la persona no «empeoró».
        for juicio in ["peor", "mal", "empeora", "cuidado"] {
            #expect(copy.lowercased().contains(juicio) == false, "«\(juicio)» juzga")
        }
    }

    /// Trend says «estable» and the two laps are equal: the row says it holds,
    /// and does not print a «0,0» difference that reads as a loss.
    @Test func holdingSteadyDoesNotPrintAZeroDifference() {
        let copy = ProgresoRowCopy.subtitle(for: entrada(score: 8.0, previousScore: 8.0, trend: "estable"))

        #expect(copy.contains("Se mantiene"))
        #expect(copy.contains("0,0") == false)
    }

    // MARK: - Lo que NO se dice

    /// The row never words `diffVsScore` as a comparison against a best
    /// attempt. On the route that holds their best attempt the value is +4,0
    /// and the sentence would be false.
    @Test func theRowNeverClaimsToCompareAgainstTheBestAttempt() {
        for trend in ["primer", "subiendo", "bajando", "estable"] {
            let copy = ProgresoRowCopy.subtitle(for: entrada(previousScore: 7.0, trend: trend, diffVsScore: 4.0))
            for prohibido in ["mejor intento", "tu mejor", "su mejor"] {
                #expect(copy.lowercased().contains(prohibido) == false, "«\(prohibido)» en «\(copy)»")
            }
        }
    }

    /// A route with no grade is not a route with a zero, and the subtitle must
    /// not manufacture a trend for it.
    @Test func aRouteWithoutAGradeSaysSoAndNothingElse() {
        let copy = ProgresoRowCopy.subtitle(for: entrada(score: nil, previousScore: nil, trend: nil))

        #expect(copy.contains("Sin nota"))
        #expect(copy.contains("Mejora") == false)
        #expect(copy.contains("0,0") == false)
    }

    @Test func anUnknownTrendFallsBackWithoutInventing() {
        let copy = ProgresoRowCopy.subtitle(for: entrada(score: 8.0, previousScore: 7.0, trend: "haciendo_el_pino"))

        #expect(copy.isEmpty == false, "algo hay que decir")
        #expect(copy.contains("Mejora") == false, "no se afirma una tendencia que no vino")
    }

    // MARK: - VoiceOver

    /// One stop per row, with the scale spoken: «8,0» alone does not say out of
    /// what, and the row is a number next to a route code.
    @Test func theSpokenLabelNamesTheRouteAndTheScale() {
        let label = ProgresoRowCopy.accessibilityLabel(for: entrada(score: 8.0, previousScore: 7.0, trend: "subiendo"))

        #expect(label.contains("1A"))
        #expect(label.contains("8,0 sobre 10"))
        #expect(label.contains("Mejora"))
    }

    @Test func theSpokenLabelOfAnUngradedRouteDoesNotSayAScore() {
        let label = ProgresoRowCopy.accessibilityLabel(for: entrada(score: nil, trend: nil))

        #expect(label.contains("sobre 10") == false)
        #expect(label.contains("Sin nota"))
    }
}
