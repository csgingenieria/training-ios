import Testing
import Foundation

@testable import Dobacksoft_Training

/// What VoiceOver hears from the widget.
///
/// The «Consultado el …» line — the only signal that a figure may be between
/// six and forty-eight hours old — was rendered at 9 pt and was **absent from
/// the accessibility label entirely**. So a VoiceOver user heard the position
/// and the mark as though they were current, with no way to learn otherwise.
///
/// That is the widget's own written rule turned against it: it refuses to show
/// a stale figure unlabelled, and then labelled it for everyone except the
/// people who cannot see the label.
///
/// The text lives in `SharedSnapshot` so it can be tested from here — the
/// widget target has no test host.
struct StandingWidgetCopyTests {
    private let t0 = Date(timeIntervalSince1970: 1_757_000_000)

    private func standing(score: Double? = 8.5, finality: StandingSnapshot.Finality = .provisional) -> StandingSnapshot.Standing {
        StandingSnapshot.Standing(
            convocatoriaName: "Oposición 2026",
            position: 12,
            totalCandidates: 256,
            score: score,
            attemptsTotal: 3,
            finality: finality
        )
    }

    private func text(
        standing: StandingSnapshot.Standing?,
        freshness: SnapshotFreshness? = .fresco,
        capturedAt: Date? = nil,
        redacted: Bool = false,
        message: String? = nil
    ) -> String {
        StandingWidgetCopy.accessibilityText(
            redacted: redacted,
            standing: standing,
            message: message,
            capturedAt: capturedAt,
            freshness: freshness
        )
    }

    // MARK: - Lo que se oye con cifras

    @Test func theFiguresAreSpokenAsASentence() {
        let spoken = text(standing: standing())
        #expect(spoken.contains("Puesto 12 de 256"))
        #expect(spoken.contains("Oposición 2026"))
        #expect(spoken.contains("Nota provisional"))
    }

    /// A settled mark is not announced as provisional.
    @Test func aSettledMarkIsNotCalledProvisional() {
        let spoken = text(standing: standing(finality: .definitiva))
        #expect(!spoken.contains("provisional"))
    }

    /// No mark is stated as missing, never as a zero and never as silence.
    @Test func aMissingMarkIsStated() {
        #expect(text(standing: standing(score: nil)).contains(SnapshotCopy.notaNoDisponible))
    }

    // MARK: - La frescura, que es lo que faltaba

    /// **The defect this closes.** An aged snapshot says when it was read.
    @Test func anAgedSnapshotSaysWhenItWasRead() {
        let spoken = text(standing: standing(), freshness: .envejecido, capturedAt: t0)
        #expect(spoken.contains("Consultado el"))
    }

    /// The control case: a fresh snapshot does NOT, so the assertion above is
    /// about staleness and not about the sentence always being there.
    @Test func aFreshSnapshotDoesNotDateItself() {
        let spoken = text(standing: standing(), freshness: .fresco, capturedAt: t0)
        #expect(!spoken.contains("Consultado el"))
    }

    /// Aged with no capture date says nothing rather than inventing one. The
    /// combination should not happen; if it does, silence beats a wrong date.
    @Test func agedWithoutADateInventsNothing() {
        let spoken = text(standing: standing(), freshness: .envejecido, capturedAt: nil)
        #expect(!spoken.contains("Consultado el"))
        #expect(spoken.contains("Puesto 12 de 256"))
    }

    /// The date is the LAST thing said. The figures come first because that is
    /// what was asked for; the caveat lands after them, the way the layout
    /// puts it under them.
    @Test func theDateIsSaidLast() throws {
        let spoken = text(standing: standing(), freshness: .envejecido, capturedAt: t0)
        let position = try #require(spoken.range(of: "Puesto 12"))
        let dated = try #require(spoken.range(of: "Consultado el"))
        #expect(position.lowerBound < dated.lowerBound)
    }

    // MARK: - Sin cifras

    /// With the device locked the figures are never spoken. This is the rule
    /// that already existed and must keep holding: VoiceOver used to read the
    /// position aloud through a locked screen.
    @Test func aLockedScreenSpeaksNoFigures() {
        let spoken = text(standing: standing(), redacted: true)
        #expect(spoken == SnapshotCopy.redactado)
        #expect(!spoken.contains("12"))
        #expect(!spoken.contains("8,5"))
    }

    /// Redaction wins over everything, staleness included.
    @Test func redactionWinsOverTheDate() {
        let spoken = text(standing: standing(), freshness: .envejecido, capturedAt: t0, redacted: true)
        #expect(spoken == SnapshotCopy.redactado)
    }

    /// Without figures the message is spoken, prefixed by the widget's name so
    /// the person knows which widget is talking.
    @Test func withoutFiguresTheMessageIsSpoken() {
        let spoken = text(standing: nil, message: SnapshotCopy.sinDatosAun)
        #expect(spoken.hasPrefix(SnapshotCopy.widgetName))
        #expect(spoken.contains(SnapshotCopy.sinDatosAun))
    }

    /// And with neither figures nor message it still says something. An empty
    /// accessibility label is a widget VoiceOver cannot describe at all.
    @Test func withNothingAtAllItStillSaysSomething() {
        let spoken = text(standing: nil, message: nil)
        #expect(!spoken.isEmpty)
        #expect(spoken.contains(SnapshotCopy.widgetName))
    }

    /// Unknown freshness dates nothing. `WidgetState.freshness` is nil when
    /// there is no snapshot at all, which is a real state and not a gap.
    @Test func unknownFreshnessDatesNothing() {
        let spoken = text(standing: standing(), freshness: nil, capturedAt: t0)
        #expect(!spoken.contains("Consultado el"))
        #expect(spoken.contains("Puesto 12 de 256"))
    }
}
