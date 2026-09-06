import Testing
import Foundation

@testable import Dobacksoft_Training

/// The sensor detects and the grade decides — two different things.
///
/// Some events are informative by design (a speed bump) and arrive with high
/// intensity while deducting exactly nothing. Showing them as incidents that
/// penalised attributes to the candidate something that never happened. This is
/// why the intensity badge was pulled until the contract could say which ones
/// actually counted.
struct EventPenaltyTests {
    private func event(
        affectsScore: Bool?,
        sensorSeverity: String? = "CRITICO",
        severity: Double? = 0.95,
        noPenaltyReason: String? = nil
    ) -> AttemptEventDTO {
        .init(
            type: "EVT_06", severity: severity, confidence: "HIGH",
            description: "x", timestamp: "09:35:02", source: "DOBACK_ELITE",
            penaltyPoints: 0.0, categoria: "FIRME",
            affectsScore: affectsScore, noPenaltyReason: noPenaltyReason,
            sensorSeverity: sensorSeverity
        )
    }

    @Test func anEventThatDeductedIsMarkedAsSuch() {
        #expect(event(affectsScore: true).didPenalise)
    }

    /// The speed bump: maximum intensity, zero points off.
    @Test func theSpeedBumpDidNotPenalise() {
        #expect(!event(affectsScore: false).didPenalise)
    }

    /// Absence is not permission to claim it penalised. That assumption is the
    /// exact error this field was added to close.
    @Test func absentFlagIsNotAPenalty() {
        #expect(!event(affectsScore: nil).didPenalise)
    }

    /// The label beats the bucketed number, which carried a 0.5 sentinel for
    /// "could not classify" that reconstructed as "moderate" — an intensity
    /// nobody measured.
    @Test func intensityPrefersTheLabel() {
        #expect(event(affectsScore: true, sensorSeverity: "LEVE", severity: 0.95).intensity == .leve)
        #expect(event(affectsScore: true, sensorSeverity: "MODERADO").intensity == .moderada)
        #expect(event(affectsScore: true, sensorSeverity: "CRITICO").intensity == .critica)
    }

    @Test func withoutLabelItFallsBackToTheNumber() {
        #expect(event(affectsScore: true, sensorSeverity: nil, severity: 0.3).intensity == .leve)
    }

    @Test func theSentinelStillClaimsNothing() {
        #expect(event(affectsScore: true, sensorSeverity: nil, severity: 0.5).intensity == nil)
        #expect(event(affectsScore: true, sensorSeverity: nil, severity: nil).intensity == nil)
    }

    @Test func nonPenalisingEventsExplainThemselves() {
        #expect(event(affectsScore: false, noPenaltyReason: "informativo")
            .noPenaltyLabel.contains("informativo"))
        #expect(event(affectsScore: false, noPenaltyReason: "franquicia")
            .noPenaltyLabel.contains("tolerancia"))
        #expect(!event(affectsScore: false, noPenaltyReason: nil).noPenaltyLabel.isEmpty)
    }

    /// The real shape, from the fixture.
    @Test func decodesBothKindsFromTheFixture() throws {
        let dto: AttemptDetailDTO = try JSONFixture.decode("attempt-detail")

        let penalising = try #require(dto.events.first { $0.didPenalise })
        #expect(penalising.intensity == .moderada)

        let informative = try #require(dto.events.first { !$0.didPenalise })
        #expect(informative.intensity == .critica)   // intensidad alta…
        #expect(informative.penaltyPoints == 0.0)    // …y cero descontado
    }
}

/// Why a breakdown row has no value.
struct BreakdownReasonTests {
    @Test func measuredRowsExplainNothing() throws {
        let dto: AttemptDetailDTO = try JSONFixture.decode("attempt-detail")
        #expect(dto.scoreBreakdown[0].unavailabilityDetail == nil)
    }

    /// "No evaluado" alone left the candidate guessing. The contract knows the
    /// reason, so the app says it.
    @Test func missingCanDataIsExplained() throws {
        let dto: AttemptDetailDTO = try JSONFixture.decode("attempt-detail")
        let frenoMotor = dto.scoreBreakdown[3]
        #expect(frenoMotor.key == "freno_motor")
        #expect(frenoMotor.unavailabilityDetail?.contains("caja") == true)
    }

    @Test func pendingEnrichmentIsExplained() throws {
        let dto: AttemptDetailDTO = try JSONFixture.decode("attempt-detail")
        #expect(dto.scoreBreakdown[4].unavailabilityDetail?.contains("flota") == true)
    }

    /// `key` is the stable identity that `family` never was.
    @Test func keyIdentifiesTheComponent() throws {
        let dto: AttemptDetailDTO = try JSONFixture.decode("attempt-detail")
        let keys = dto.scoreBreakdown.compactMap(\.key)
        #expect(keys.count == 5)
        #expect(Set(keys).count == 5)
    }
}
