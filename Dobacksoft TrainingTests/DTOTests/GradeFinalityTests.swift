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
        #expect(GradeFinality.unknown.note == nil, "un estado desconocido no afirma nada")
    }

    /// The portal prints «No tienen efecto jurídico hasta el cierre oficial de
    /// la convocatoria» on every page. The client only said the mark «puede
    /// variar», which is the mild half: what a candidate needs to know is that
    /// nothing on this screen is yet a decision about them.
    @Test func theProvisionalNoteStatesItHasNoLegalEffect() throws {
        let note = try #require(GradeFinality.provisional.note)
        #expect(note.contains("efecto jurídico"))
        #expect(note.contains("cierre oficial"))
    }

    /// A settled mark says so. Silence read as «still provisional», which is
    /// the opposite of true once the convocatoria is locked.
    @Test func theDefinitiveNoteSaysTheMarkNoLongerMoves() throws {
        let note = try #require(GradeFinality.definitive.note)
        #expect(note.contains("definitiv"))
        #expect(!note.contains("provisional"))
    }

    /// The closing date is appended only where it describes a close that has
    /// already happened. On an open convocatoria `closedAt` is nil by contract
    /// — it is not a future deadline — so the provisional note ignores it
    /// rather than inventing «cierra el».
    @Test func theClosingDateIsAppendedOnlyWhereItHasHappened() throws {
        let closed = "2026-10-12T00:00:00Z"

        let definitive = try #require(GradeFinality.definitive.note(closedAt: closed))
        #expect(definitive.contains("12/10/2026"))

        let pending = try #require(GradeFinality.pendingConfirmation.note(closedAt: closed))
        #expect(pending.contains("12/10/2026"))

        let provisional = try #require(GradeFinality.provisional.note(closedAt: closed))
        #expect(!provisional.contains("12/10/2026"), "una convocatoria abierta no tiene fecha de cierre")

        #expect(GradeFinality.unknown.note(closedAt: closed) == nil)
    }

    /// Without a date the overload returns exactly the plain note: a dangling
    /// «()» or a stray separator would be worse than saying nothing.
    @Test func withoutADateTheNoteIsUnchanged() {
        for finality in [GradeFinality.provisional, .pendingConfirmation, .definitive, .unknown] {
            #expect(finality.note(closedAt: nil) == finality.note)
        }
    }

    /// `/me/progress` and `/me/routes/<code>` do not send the convocatoria
    /// status — only `closedAt`, documented as nil while it is open. So those
    /// two screens derive the floor: open means provisional, closed means at
    /// most pending confirmation. Never `.definitive`, because from a date
    /// alone CLOSED and LOCKED are indistinguishable and only LOCKED settles
    /// the mark.
    @Test func aClosingDateAloneNeverClaimsTheMarkIsSettled() {
        #expect(GradeFinality(convocatoriaClosedAt: nil) == .provisional)
        #expect(GradeFinality(convocatoriaClosedAt: "2026-10-12T00:00:00Z") == .pendingConfirmation)
        #expect(GradeFinality(convocatoriaClosedAt: "   ") == .provisional, "una cadena vacía no es una fecha")
    }

    /// **The app and the widget cannot contradict each other about a
    /// provisional result.**
    ///
    /// They cannot be identical — the app has room for the explanation and the
    /// widget does not — so the property that holds is containment: the
    /// widget's sentence is exactly how the app's begins.
    ///
    /// This is the drift that started the same day the app's wording changed:
    /// `GradeFinality` gained «no tiene efecto jurídico» and the widget went on
    /// saying only that the mark may vary. The widget is the surface other
    /// people see, sitting on someone's home screen.
    @Test func theWidgetSaysTheFirstHalfOfWhatTheAppSays() throws {
        let app = try #require(GradeFinality.provisional.note)
        #expect(app.hasPrefix(SnapshotCopy.notaProvisionalDetalle))
        #expect(SnapshotCopy.notaProvisionalDetalle == LegalNotice.provisionalHasNoLegalEffect)
        #expect(app.count > SnapshotCopy.notaProvisionalDetalle.count,
                "si fueran iguales, este test no estaría comprobando la contención")
    }

    /// No explanation — in any state, with or without a date — may hint at
    /// admission, seats or a verdict.
    @Test func noExplanationEverLeavesArticle22() {
        let notes = [GradeFinality.provisional, .pendingConfirmation, .definitive, .unknown]
            .flatMap { [$0.note, $0.note(closedAt: "2026-10-12T00:00:00Z")] }
            .compactMap { $0 }

        #expect(!notes.isEmpty, "si no hay ninguna frase que revisar, este test no prueba nada")

        for note in notes.map({ $0.lowercased() }) {
            for banned in ["apto", "plaza", "corte", "admit", "aprob", "suspens", "exclu"] {
                #expect(!note.contains(banned), "«\(banned)» aparece en: \(note)")
            }
        }
    }
}
