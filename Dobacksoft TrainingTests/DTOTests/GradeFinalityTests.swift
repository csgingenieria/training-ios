import Testing
import Foundation

@testable import Dobacksoft_Training

struct GradeFinalityTests {
    @Test func closedAndLockedAreDefinitive() {
        #expect(GradeFinality(convocatoriaStatus: "CLOSED") == .definitive)
        #expect(GradeFinality(convocatoriaStatus: "LOCKED") == .definitive)
    }

    @Test func openStatesAreProvisional() {
        #expect(GradeFinality(convocatoriaStatus: "OPEN") == .provisional)
        #expect(GradeFinality(convocatoriaStatus: "PREVIEW") == .provisional)
        #expect(GradeFinality(convocatoriaStatus: "CLOSING") == .provisional)
    }

    @Test func parsingIsCaseInsensitiveAndTrims() {
        #expect(GradeFinality(convocatoriaStatus: "  closed ") == .definitive)
    }

    /// Absent or unrecognised status claims nothing. Defaulting to "definitive"
    /// would assert a grade is final when nobody said so; defaulting to
    /// "provisional" would contradict a closed convocatoria. Silence is honest.
    @Test func unknownStatusMakesNoClaim() {
        #expect(GradeFinality(convocatoriaStatus: nil) == .unknown)
        #expect(GradeFinality(convocatoriaStatus: "") == .unknown)
        #expect(GradeFinality(convocatoriaStatus: "ARCHIVED") == .unknown)
    }

    @Test func onlyProvisionalCarriesALabel() {
        #expect(GradeFinality.provisional.scoreLabel == "Nota provisional")
        #expect(GradeFinality.definitive.scoreLabel == "Nota")
        #expect(GradeFinality.unknown.scoreLabel == "Nota")
    }

    @Test func provisionalExplainsItself() {
        #expect(GradeFinality.provisional.note != nil)
        #expect(GradeFinality.definitive.note == nil)
        #expect(GradeFinality.unknown.note == nil)
    }

    /// The explanation must not hint at admission, seats or a verdict.
    @Test func theExplanationStaysWithinArticle22() throws {
        let note = try #require(GradeFinality.provisional.note).lowercased()
        for banned in ["apto", "plaza", "corte", "admit", "aprob", "suspens"] {
            #expect(!note.contains(banned), "«\(banned)» aparece en: \(note)")
        }
    }
}
