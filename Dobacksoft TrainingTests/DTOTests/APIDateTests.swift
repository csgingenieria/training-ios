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

    @Test func todasKeepsEverything() {
        for status in ["OPEN", "CLOSED", "LOCKED", nil] {
            #expect(ConvocatoriaScope.todas.matches(convocatoria(status: status)))
        }
    }
}
