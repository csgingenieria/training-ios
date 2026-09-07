import Testing
import Foundation

@testable import Dobacksoft_Training

/// The backend sends ISO-8601 UTC. Five screens were printing it raw, so a
/// firefighter read `2026-09-03T14:22:11Z`.
struct APIDateTests {
    @Test func parsesISO8601WithZulu() {
        let date = APIDate.parse("2026-09-03T14:22:11Z")
        #expect(date != nil)
    }

    /// The backend emits fractional seconds on some endpoints and not on
    /// others. Both must parse, or one screen silently shows nothing.
    @Test func parsesWithAndWithoutFractionalSeconds() {
        #expect(APIDate.parse("2026-09-03T14:22:11Z") != nil)
        #expect(APIDate.parse("2026-09-03T14:22:11.482Z") != nil)
    }

    @Test func parsesExplicitOffsets() {
        #expect(APIDate.parse("2026-09-03T16:22:11+02:00") != nil)
    }

    @Test func rejectsGarbageAndEmptiness() {
        #expect(APIDate.parse(nil) == nil)
        #expect(APIDate.parse("") == nil)
        #expect(APIDate.parse("ayer por la tarde") == nil)
    }

    /// Times are shown in Madrid, where the examination happens — not in UTC.
    /// 14:22 UTC in September is 16:22 in Madrid.
    @Test func formatsInMadridTime() {
        let text = APIDate.shortDateTime("2026-09-03T14:22:11Z")
        #expect(text == "03/09/2026 16:22")
    }

    @Test func dateOnlyDropsTheTime() {
        #expect(APIDate.shortDate("2026-09-03T14:22:11Z") == "03/09/2026")
    }

    /// An unparseable value must not surface as a broken string: the caller
    /// decides what to show instead.
    @Test func unparseableValuesYieldNil() {
        #expect(APIDate.shortDateTime("no soy una fecha") == nil)
        #expect(APIDate.shortDateTime(nil) == nil)
    }

    /// Relative wording is what makes an instructor's activity list readable.
    @Test func describesRecentInstantsRelatively() {
        let now = Date(timeIntervalSince1970: 1_757_000_000)
        let fiveMinutesAgo = now.addingTimeInterval(-300)
        let text = APIDate.relative(from: fiveMinutesAgo, to: now)
        #expect(text.contains("5"))
    }

    /// Long-format wording for the widget footnote.
    @Test func longFormatSpellsTheMonth() {
        let text = APIDate.longDateTime(Date(timeIntervalSince1970: 1_757_000_000))
        #expect(text.contains("de"))
    }
}

/// The web splits convocatorias into "in progress" and "closed"; the app had
/// them all in one list.
struct ConvocatoriaScopeTests {
    private func convocatoria(status: String?) -> ConvocatoriaSummaryDTO {
        ConvocatoriaSummaryDTO(
            id: "c",
            name: "Convocatoria",
            description: nil,
            status: status,
            totalCandidates: 10,
            closedAt: nil,
            updatedAt: nil
        )
    }

    @Test func openStatesCountAsInProgress() {
        #expect(ConvocatoriaScope.activas.matches(convocatoria(status: "OPEN")))
        #expect(ConvocatoriaScope.activas.matches(convocatoria(status: "PREVIEW")))
        #expect(ConvocatoriaScope.activas.matches(convocatoria(status: "CLOSING")))
    }

    @Test func closedAndLockedCountAsClosed() {
        #expect(ConvocatoriaScope.cerradas.matches(convocatoria(status: "CLOSED")))
        #expect(ConvocatoriaScope.cerradas.matches(convocatoria(status: "LOCKED")))
    }

    /// An unknown status must not vanish from every filter. Defaulting to
    /// "in progress" keeps it visible where the instructor works.
    @Test func unknownStatusStaysVisible() {
        #expect(ConvocatoriaScope.activas.matches(convocatoria(status: "ARCHIVED")))
        #expect(ConvocatoriaScope.activas.matches(convocatoria(status: nil)))
        #expect(!ConvocatoriaScope.cerradas.matches(convocatoria(status: nil)))
    }

    /// PREVIEW and CLOSING are real backend states. Treating them as closed
    /// made a convocatoria being wrapped up lose its candidates from the
    /// instructor's search — exactly when he needs to know who is missing.
    @Test func previewAndClosingAreStillInProgress() {
        #expect(ConvocatoriaScope.activas.matches(convocatoria(status: "PREVIEW")))
        #expect(ConvocatoriaScope.activas.matches(convocatoria(status: "CLOSING")))
        #expect(!ConvocatoriaScope.cerradas.matches(convocatoria(status: "CLOSING")))
    }

    @Test func todasKeepsEverything() {
        for status in ["OPEN", "CLOSED", "LOCKED", nil] {
            #expect(ConvocatoriaScope.todas.matches(convocatoria(status: status)))
        }
    }
}

/// The API is not homogeneous about instants, and assuming it was cost a
/// regression: event times vanished from the attempt detail.
struct DisplayInstantTests {
    /// Events arrive already formatted in Madrid time (`%H:%M:%S` from the
    /// backend's own helper), not as ISO. Parsing them as ISO yields nil and
    /// the whole column goes blank.
    @Test func preformattedTimeSurvives() {
        #expect(APIDate.displayInstant("08:33:12") == "08:33:12")
    }

    @Test func isoStillGetsFormatted() {
        #expect(APIDate.displayInstant("2026-09-03T14:22:11Z") == "03/09/2026 16:22")
    }

    /// The backend writes a dash when an event has no timestamp. That is
    /// absence, not a value to print.
    @Test func absenceMarkersAreDropped() {
        #expect(APIDate.displayInstant("—") == nil)
        #expect(APIDate.displayInstant("-") == nil)
        #expect(APIDate.displayInstant("  ") == nil)
        #expect(APIDate.displayInstant(nil) == nil)
    }
}

/// `HH:mm` alone, for «Actualizado a las …».
///
/// The date is redundant there — the data was read in this session, minutes
/// ago — and printing `03/09/2026 16:22` under a grade reads like the date OF
/// the grade, which is a different and more important fact.
@Suite struct APIDateTimeOfDayTests {
    /// Fixed instant, and asserted in the exam's time zone: a formatter using
    /// the device zone would show an instructor on a trip an hour that does not
    /// match the portal or the record.
    @Test func theTimeIsPrintedInMadridWithoutTheDate() {
        // 2026-09-07T18:22:00Z → 20:22 en Madrid (CEST, UTC+2).
        let instante = try! #require(APIDate.parse("2026-09-07T18:22:00Z"))

        #expect(APIDate.time(instante) == "20:22")
    }

    @Test func midnightIsZeroPadded() {
        let instante = try! #require(APIDate.parse("2026-01-15T23:05:00Z"))

        // 23:05Z en enero → 00:05 del día siguiente en Madrid (CET, UTC+1).
        #expect(APIDate.time(instante) == "00:05")
    }
}
