import Testing
import Foundation

@testable import Dobacksoft_Training

struct GradeFinalityTests {
    /// Only LOCKED is truly final.
    @Test func onlyLockedIsDefinitive() {
        #expect(GradeFinality(convocatoriaStatus: "LOCKED") == .definitive)
    }

    /// CLOSED means the record is signed but still inside the 24-hour window
    /// in which an administrator can revoke the closure. Calling that grade
    /// "final" tells a candidate their result cannot change when it still can.
    @Test func closedIsStillRevocable() {
        #expect(GradeFinality(convocatoriaStatus: "CLOSED") == .pendingConfirmation)
        #expect(GradeFinality(convocatoriaStatus: "CLOSED").note?.contains("24 horas") == true)
    }

    /// A closure begun is not a closure done.
    @Test func closingIsStillProvisional() {
        #expect(GradeFinality(convocatoriaStatus: "CLOSING") == .provisional)
    }

    @Test func openStatesAreProvisional() {
        #expect(GradeFinality(convocatoriaStatus: "OPEN") == .provisional)
        #expect(GradeFinality(convocatoriaStatus: "PREVIEW") == .provisional)
        #expect(GradeFinality(convocatoriaStatus: "CLOSING") == .provisional)
    }

    @Test func parsingIsCaseInsensitiveAndTrims() {
        #expect(GradeFinality(convocatoriaStatus: "  locked ") == .definitive)
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
        #expect(GradeFinality.pendingConfirmation.scoreLabel == "Nota pendiente de confirmación")
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
