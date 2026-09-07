import Testing
import Foundation

@testable import Dobacksoft_Training

/// Notes are written the way the web portal writes them.
///
/// The app printed «8.50» in eleven places — a dot, and two decimals — while
/// the portal the client already accepted prints «8,5». Spanish uses a comma,
/// and a candidate reading one figure on the phone and another on the portal is
/// not looking at the same system.
struct ScoreFormatTests {
    /// One attempt's own note: one decimal, matching `%.1f` in the portal's
    /// `resultados.html` and `alumno.html`.
    @Test func anAttemptNoteTakesOneDecimal() {
        #expect(ScoreFormat.attempt(8.5) == "8,5")
        #expect(ScoreFormat.attempt(10.0) == "10,0")
        #expect(ScoreFormat.attempt(0.0) == "0,0")
    }

    /// Aggregates keep two, because a mean over ten routes lands on quarters
    /// and 4,75 rounded to 4,8 is a different number from the one on the record.
    @Test func aggregatesKeepTwoDecimals() {
        #expect(ScoreFormat.aggregate(4.75) == "4,75")
        #expect(ScoreFormat.aggregate(0.85) == "0,85")
        #expect(ScoreFormat.aggregate(9.5) == "9,50")
    }

    @Test func breakdownComponentsKeepTwoDecimals() {
        #expect(ScoreFormat.component(3.75) == "3,75")
        #expect(ScoreFormat.component(2.21) == "2,21")
        #expect(ScoreFormat.component(0.0) == "0,00")
    }

    /// The separator is fixed, not taken from the device.
    ///
    /// Every label around the number is hardcoded Spanish, so a phone set to
    /// English must not start printing «8.5» in the middle of it.
    @Test func neverADot() {
        let all = [
            ScoreFormat.attempt(8.5), ScoreFormat.attempt(0.0),
            ScoreFormat.aggregate(4.75), ScoreFormat.aggregate(10.0),
            ScoreFormat.component(1.875),
        ]
        for text in all {
            #expect(!text.contains("."), "«\(text)» lleva punto decimal")
            #expect(text.contains(","))
        }
    }

    /// The rounding a real payload produces, so the numbers on screen are the
    /// ones staging actually returned for a live attempt.
    @Test func realPayloadRoundsAsThePortalDoes() {
        // attempt 94815dce… : score 8.5, allison and webfleet weights 1.875.
        #expect(ScoreFormat.attempt(8.5) == "8,5")
        #expect(ScoreFormat.component(1.875) == "1,88")
        // ranking leader: 9.5 average over 10 required routes -> 4.75 official.
        #expect(ScoreFormat.aggregate(9.5) == "9,50")
        #expect(ScoreFormat.aggregate(4.75) == "4,75")
    }
}
