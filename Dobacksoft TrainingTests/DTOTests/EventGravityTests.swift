import Testing
import Foundation

@testable import Dobacksoft_Training

/// The gravity the event was GRADED with — the datum the sheet never showed.
///
/// `categoria` has been decoded since the DTO existed and no view ever rendered
/// it. What the card shows instead is the sensor's intensity, and the backend
/// names that field for exactly what it is: «intensidad del canal, no la
/// gravedad con la que se puntuó». So the screen answered a question the
/// candidate was not asking and stayed silent on the one he was.
///
/// It matters because this is a public examination: «Grave» versus «Leve» is
/// what lets a candidate understand a deduction, and — if he disagrees — what
/// lets him name it when he asks for a review.
struct EventGravityTests {
    private func event(categoria: String?, affectsScore: Bool? = true) -> AttemptEventDTO {
        AttemptEventDTO(
            type: "EVT_01",
            severity: 0.9,
            confidence: "HIGH",
            description: nil,
            timestamp: nil,
            source: "DOBACK_ELITE",
            penaltyPoints: 1.0,
            categoria: categoria,
            affectsScore: affectsScore,
            noPenaltyReason: nil,
            sensorSeverity: "CRITICO"
        )
    }

    // MARK: - El dominio real

    /// The three values `CATEGORIA_LABELS` defines in the backend, and only
    /// those. The fixture used to carry `ESTABILIDAD` and `FIRME`, which are
    /// FAMILY values — where the event deducted, not how gravely.
    @Test func theThreeGravitiesReadAsCastilian() {
        #expect(event(categoria: "LEVE").gravity == .leve)
        #expect(event(categoria: "MODERADA").gravity == .moderada)
        #expect(event(categoria: "GRAVE").gravity == .grave)

        #expect(AttemptEventDTO.Gravity.leve.label == "Leve")
        #expect(AttemptEventDTO.Gravity.moderada.label == "Moderada")
        #expect(AttemptEventDTO.Gravity.grave.label == "Grave")
    }

    @Test func casingAndWhitespaceDoNotHideTheGravity() {
        #expect(event(categoria: "grave").gravity == .grave)
        #expect(event(categoria: "  Moderada  ").gravity == .moderada)
    }

    /// Absence is absence: nothing is asserted about an event whose gravity the
    /// contract does not state, and nothing is drawn.
    @Test func anEventWithoutGravitySaysNothing() {
        #expect(event(categoria: nil).gravity == nil)
        #expect(event(categoria: "").gravity == nil)
        #expect(event(categoria: "UNA_QUE_NO_CONOCEMOS").gravity == nil)
    }

    // MARK: - El color, que es donde se puede mentir

    /// An event that did not deduct is not painted as damage, whatever its
    /// gravity. The card already carries this reasoning for the sensor
    /// intensity: an informative event — the speed bump — arrives graded and
    /// deducts nothing, and colouring it red attributes to the candidate
    /// something that did not happen.
    @Test func aGravityThatDidNotDeductIsNotPaintedAsDamage() {
        #expect(event(categoria: "GRAVE", affectsScore: false).gravityBadgeKind == .neutral)
        #expect(event(categoria: "MODERADA", affectsScore: false).gravityBadgeKind == .neutral)
        #expect(event(categoria: "GRAVE", affectsScore: nil).gravityBadgeKind == .neutral,
                "sin contrato que lo afirme tampoco se colorea")
    }

    /// When it did deduct, the colour carries the weight the tribunal gave it.
    @Test func aGravityThatDeductedCarriesItsWeight() {
        #expect(event(categoria: "GRAVE", affectsScore: true).gravityBadgeKind == .danger)
        #expect(event(categoria: "MODERADA", affectsScore: true).gravityBadgeKind == .warning)
        #expect(event(categoria: "LEVE", affectsScore: true).gravityBadgeKind == .neutral)
    }

    /// No badge at all when there is no gravity: an empty capsule would be a
    /// statement of its own.
    @Test func noGravityMeansNoBadge() {
        #expect(event(categoria: nil).gravity == nil)
    }

    // MARK: - Lo que NO es

    /// Gravity and sensor intensity are different questions and must not
    /// collapse into one another: this event is graded LEVE while the channel
    /// registered it as critical, and both statements are true.
    @Test func gravityIsNotTheSensorIntensity() {
        let leve = event(categoria: "LEVE")

        #expect(leve.gravity == .leve)
        #expect(leve.intensity == .critica, "el sensor midió otra cosa, y sigue diciendo lo suyo")
    }
}
