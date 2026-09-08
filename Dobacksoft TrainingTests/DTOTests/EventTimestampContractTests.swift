import Testing
import Foundation

@testable import Dobacksoft_Training

/// How the client handles `events[].timestamp` today — the question the backend
/// asked before deciding whether to change the format or add a field.
///
/// The same event arrives in two shapes. On the attempt sheet it is
/// `"09:32:11"`: a wall-clock time with no date and no zone, formatted for a
/// template cell. On the map it is `"2026-09-01T08:00:20"`: ISO in Madrid time
/// with no explicit offset.
///
/// The answer, pinned here rather than asserted from memory: **as text**. Both
/// fields decode into `String?`, never into `Date`. The feared two-hour drift
/// never happened, because the parser rejected the map's zoneless shape
/// outright and dropped the instant instead of misreading it — worse, and
/// harder to see on screen.
///
/// The map's format is now corrected to `+02:00`. These tests also pin the
/// near-miss, and pin it the other way round from how it was assumed: `+0200`
/// without the colon parses here too. What this client cannot read is a
/// timestamp with no zone at all.
///
/// The sheet's wall-clock time remains: it is a published field, so changing
/// it would not be additive.
struct EventTimestampContractTests {
    // MARK: - Lo que hace el parser hoy

    /// The sheet's shape is not a date and is not read as one. No date is
    /// invented for it — which is right, and is also why the sheet cannot say
    /// which DAY the event belongs to.
    @Test func theSheetsWallClockTimeIsNotADate() {
        #expect(APIDate.parse("09:32:11") == nil)
    }

    /// The map's shape is ALSO rejected, and that is the load-bearing fact:
    /// `ISO8601DateFormatter` with `.withInternetDateTime` requires an explicit
    /// zone designator, so a zoneless ISO string never parses.
    ///
    /// So the client is not silently reading Madrid time as UTC — it is
    /// dropping the instant. No two-hour drift, no wrong instant on screen,
    /// but no instant either.
    @Test func theMapsZonelessISOIsRejectedRatherThanReadAsUTC() {
        #expect(APIDate.parse("2026-09-01T08:00:20") == nil)
        #expect(APIDate.shortDateTime("2026-09-01T08:00:20") == nil)
    }

    /// The control case: with an explicit offset the very same instant parses
    /// and renders in Madrid time. Without this, the two tests above would
    /// pass for a parser that simply never worked.
    @Test func withAnExplicitZoneTheSameInstantParsesAndRendersInMadrid() throws {
        let rendered = try #require(APIDate.shortDateTime("2026-09-01T08:00:20Z"))
        // 08:00:20 UTC is 10:00 in Madrid in September (CEST, +02:00). This is
        // the drift that a zoneless string would have hidden.
        #expect(rendered == "01/09/2026 10:00")

        #expect(APIDate.shortDateTime("2026-09-01T10:00:20+02:00") == rendered,
                "el mismo instante escrito con su desplazamiento local")
    }

    /// What the attempt sheet actually shows: the raw string, verbatim.
    ///
    /// `displayInstant` falls back to the literal when it cannot parse, which
    /// is why the screen reads «09:32:11» and not an empty cell. Honest, and
    /// undatable.
    @Test func theSheetShowsTheRawTimeVerbatim() {
        #expect(APIDate.displayInstant("09:32:11") == "09:32:11")
    }

    // MARK: - Un formato con zona, y el que parece llevarla y no vale

    /// The corrected shape parses. This is the fix landing.
    @Test func theCorrectedOffsetFormatParses() throws {
        let rendered = try #require(APIDate.shortDateTime("2026-09-01T10:00:20+02:00"))
        #expect(rendered == "01/09/2026 10:00")
    }

    /// **`+0200`, without the colon, ALSO parses here.** Measured, not assumed.
    ///
    /// This is worth stating precisely because it was assumed the other way.
    /// The colonless offset is valid ISO 8601 and not valid RFC 3339, and
    /// `.withInternetDateTime` is documented as wanting RFC 3339 — so the
    /// reasonable expectation is a rejection. `ISO8601DateFormatter` accepts it
    /// anyway.
    ///
    /// What matters: whatever rejected the colonless form was not this client.
    /// The first fix on the producing side would have worked for us.
    ///
    /// It is pinned so that nobody re-derives the strict answer from the
    /// documentation instead of from the parser.
    @Test func anOffsetWithoutItsColonAlsoParsesHere() {
        #expect(APIDate.parse("2026-09-01T10:00:20+0200") != nil)
        #expect(APIDate.parse("2026-09-01T10:00:20+02:00") != nil)
    }

    /// All three spellings of the same instant agree. What the client cannot
    /// read is a timestamp with NO zone at all — which is the actual defect,
    /// and the one that got fixed.
    @Test func everySpellingWithAZoneIsTheSameInstant() throws {
        let zulu = try #require(APIDate.parse("2026-09-01T08:00:20Z"))
        #expect(APIDate.parse("2026-09-01T10:00:20+02:00") == zulu)
        #expect(APIDate.parse("2026-09-01T10:00:20+0200") == zulu)
        #expect(APIDate.parse("2026-09-01T10:00:20") == nil, "sin zona no hay instante")
    }

    // MARK: - El cruce entre las dos pantallas

    /// Both sides of the join carry a real backend `id`, so the join runs on
    /// the identifier and never on the timestamp.
    ///
    /// This test replaces one that claimed the opposite. That claim was checked
    /// against `Fixtures/attempt-detail.json` — this repository's own
    /// hand-written test fixture, invented data and all — and reported as
    /// though it had been checked against the endpoint. A fixture is an
    /// artefact we wrote; it cannot testify about the contract.
    @Test func bothSidesOfTheJoinCarryARealIdentifier() throws {
        let sheet = try JSONDecoder().decode(AttemptEventDTO.self, from: Data("""
        {
          "id": "d24bd48c-9353-485e-825b-79687334c9c6",
          "type": "EVT_06",
          "timestamp": "09:32:11"
        }
        """.utf8))

        let map = try JSONDecoder().decode(GpsEventDTO.self, from: Data("""
        {
          "id": "d24bd48c-9353-485e-825b-79687334c9c6",
          "type": "EVT_06",
          "timestamp": "2026-09-01T10:00:20+02:00",
          "lat": 40.41,
          "lng": -3.70
        }
        """.utf8))

        #expect(sheet.id == map.id, "el mismo evento, la misma identidad")
        #expect(map.coordinate != nil)
    }

    /// The derivation survives only as a fallback, for an event that arrives
    /// without one. `Identifiable` in a `ForEach` cannot have two rows share an
    /// id — SwiftUI reuses the wrong row — so there has to be something.
    @Test func anEventWithoutAnIdStillGetsOne() throws {
        let event = try JSONDecoder().decode(AttemptEventDTO.self, from: Data("""
        { "type": "EVT_01", "timestamp": "09:32:11" }
        """.utf8))

        #expect(event.id == "EVT_01-09:32:11")
    }

    /// And the real id WINS over the derivation. Without this the client would
    /// keep joining on a made-up key while a perfectly good one travelled in
    /// the payload.
    @Test func theRealIdWinsOverTheDerivedOne() throws {
        let event = try JSONDecoder().decode(AttemptEventDTO.self, from: Data("""
        { "id": "ev-real", "type": "EVT_01", "timestamp": "09:32:11" }
        """.utf8))

        #expect(event.id == "ev-real")
        #expect(event.timestamp == "09:32:11", "se conserva tal cual, sin normalizar")
    }

    /// A blank id is not an id. The sentinel rules apply here as everywhere:
    /// an empty string would make every unidentified event collide on "".
    @Test func aBlankIdFallsBackToTheDerivation() throws {
        let event = try JSONDecoder().decode(AttemptEventDTO.self, from: Data("""
        { "id": "   ", "type": "EVT_01", "timestamp": "09:32:11" }
        """.utf8))

        #expect(event.id == "EVT_01-09:32:11")
    }
}
