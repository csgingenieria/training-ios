import Testing
import Foundation

@testable import Dobacksoft_Training

/// What the gearbox card says about compliance.
///
/// This is where the backend's ⚠ becomes a sentence, and where a plausible
/// implementation states something false: `compliancePct` caps at 100 and
/// `rawCompliancePct` does not, so a card printing one of them as «cumplimiento»
/// either credits the candidate with a compliance the criterion does not award,
/// or hides that they exceeded the minimum.
struct AllisonCopyTests {
    private func allison(
        presses: Int? = 7,
        minimumPresses: Int? = 5,
        compliancePct: Double? = 100.0,
        rawCompliancePct: Double? = 140.0,
        evaluated: Bool? = true,
        reason: String? = nil
    ) -> AllisonDTO {
        AllisonDTO(
            evaluated: evaluated, reason: reason,
            presses: presses, minimumPresses: minimumPresses,
            compliancePct: compliancePct, rawCompliancePct: rawCompliancePct,
            outOfTen: 10.0, deduction: 0.0, weight: 0.15, max: 1.5,
            contribution: 1.5, maxPenalty: 1.5, curveExponent: 1.0
        )
    }

    // MARK: - Cumplimiento

    /// Exceeding the minimum is stated as exceeding it, and the card does not
    /// print «140 % de cumplimiento» — the criterion caps the credit at 100 and
    /// saying otherwise awards something it does not award.
    @Test func exceedingTheMinimumIsSaidWithoutInflatingTheCompliance() {
        let copy = AllisonCopy.compliance(allison(compliancePct: 100.0, rawCompliancePct: 140.0))

        #expect(copy.contains("140") == false, "«\(copy)» acredita un cumplimiento que el criterio no da")
        #expect(copy.contains("por encima") || copy.contains("supera") || copy.contains("más"),
                "«\(copy)» no dice que se pasó del mínimo")
    }

    /// …and it does not hide it either. The candidate pressed more than
    /// required and the card has to acknowledge it.
    @Test func exceedingTheMinimumIsNotHiddenBehindTheCap() {
        let justo = AllisonCopy.compliance(allison(compliancePct: 100.0, rawCompliancePct: 100.0))
        let pasado = AllisonCopy.compliance(allison(compliancePct: 100.0, rawCompliancePct: 140.0))

        #expect(justo != pasado, "cumplir justo y pasarse no pueden decirse igual")
    }

    @Test func fallingShortStatesThePercentageThatCounts() {
        let copy = AllisonCopy.compliance(allison(compliancePct: 60.0, rawCompliancePct: 60.0))

        #expect(copy.contains("60"))
    }

    /// Descriptive, never a verdict on the person: the gearbox was used less
    /// than required, and that is a fact about the lap.
    @Test func fallingShortDoesNotJudgeTheCandidate() {
        let copy = AllisonCopy.compliance(allison(compliancePct: 40.0, rawCompliancePct: 40.0)).lowercased()

        for juicio in ["mal", "deficiente", "insuficiente", "debería", "tiene que"] {
            #expect(copy.contains(juicio) == false, "«\(juicio)» juzga a la persona")
        }
    }

    @Test func withoutPercentagesNothingIsClaimed() {
        let copy = AllisonCopy.compliance(allison(compliancePct: nil, rawCompliancePct: nil))

        #expect(copy.isEmpty == false, "algo hay que decir")
        #expect(copy.contains("%") == false, "no se inventa un porcentaje")
    }

    // MARK: - Sin evaluar

    /// The reasons are the same vocabulary the score breakdown already uses, so
    /// the sheet does not word the same cause two ways.
    @Test func aKnownReasonIsExplainedInWords() {
        let copy = AllisonCopy.unevaluated(reason: "sin_datos_can")

        #expect(copy.contains("_") == false, "«\(copy)» enseña el código crudo")
        #expect(copy.isEmpty == false)
    }

    @Test func anUnknownReasonStillSaysItCouldNotBeMeasured() {
        let copy = AllisonCopy.unevaluated(reason: "un_motivo_de_mañana")

        #expect(copy.contains("no se pudo") || copy.contains("No se pudo"))
        #expect(copy.contains("un_motivo_de_mañana") == false, "el código crudo no se enseña")
    }

    @Test func noReasonAtAllIsStillExplained() {
        #expect(AllisonCopy.unevaluated(reason: nil).isEmpty == false)
    }
}
