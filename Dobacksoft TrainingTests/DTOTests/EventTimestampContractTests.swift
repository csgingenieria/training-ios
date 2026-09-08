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
/// fields decode into `String?`, never into `Date`. What that means in practice
/// is what these tests establish — including that the feared two-hour drift
/// does not happen, because the parser rejects the map's shape outright and
/// drops the instant instead of misreading it.
///
/// When the contract changes, these tests are the ones that must be updated,
/// and they say what the change is expected to fix.
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

    // MARK: - Por qué el cruce entre las dos pantallas no puede hacerse hoy

    /// The map's event carries a real backend `id`. The sheet's does not: its
    /// `id` is DERIVED from type and timestamp, because the contract sends no
    /// identifier for it (checked against the frozen response, not assumed).
    ///
    /// So the join block B was designed for cannot run from the sheet side at
    /// all, and the only key left — type plus timestamp — is exactly the pair
    /// whose format differs between the two endpoints.
    @Test func theSheetsEventIdIsDerivedFromTheTimestampItself() throws {
        let json = Data("""
        {
          "type": "EVT_01",
          "severity": 0.6,
          "timestamp": "09:32:11"
        }
        """.utf8)

        let event = try JSONDecoder().decode(AttemptEventDTO.self, from: json)
        #expect(event.id == "EVT_01-09:32:11")
        #expect(event.timestamp == "09:32:11", "se conserva tal cual, sin normalizar")
    }

    /// And the map's event keeps the identifier it is given, so the missing
    /// half of the join is on the sheet side.
    @Test func theMapsEventKeepsTheIdentifierItIsGiven() throws {
        let json = Data("""
        {
          "id": "ev-8891",
          "type": "EVT_01",
          "timestamp": "2026-09-01T08:00:20",
          "lat": 40.41,
          "lng": -3.70
        }
        """.utf8)

        let event = try JSONDecoder().decode(GpsEventDTO.self, from: json)
        #expect(event.id == "ev-8891")
        #expect(event.coordinate != nil)
    }
}
