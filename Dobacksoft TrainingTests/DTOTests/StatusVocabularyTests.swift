import Testing
import Foundation

@testable import Dobacksoft_Training

/// Badges used to render the backend's own enum values, so a firefighter read
/// "ACTIVE" under «Estado de su matrícula» and "OPEN" over their convocatoria.
struct StatusVocabularyTests {
    // MARK: - Matrícula

    @Test func enrolmentStatesReadAsSpanish() {
        #expect(StatusVocabulary.enrolment("ACTIVE").label == "Activa")
        #expect(StatusVocabulary.enrolment("WITHDRAWN").label == "Baja")
        #expect(StatusVocabulary.enrolment("INVALIDATED").label == "Anulada")
    }

    /// The backend has sent Spanish values for this field too, and casing and
    /// stray whitespace have both shown up in real payloads.
    @Test func enrolmentToleratesTheFormsTheBackendActuallySends() {
        #expect(StatusVocabulary.enrolment("activa") == StatusVocabulary.enrolment("ACTIVE"))
        #expect(StatusVocabulary.enrolment("  active  ") == StatusVocabulary.enrolment("ACTIVE"))
        #expect(StatusVocabulary.enrolment("BAJA") == StatusVocabulary.enrolment("WITHDRAWN"))
    }

    @Test func onlyLosingTheEnrolmentIsAlarming() {
        #expect(StatusVocabulary.enrolment("ACTIVE").kind == .success)
        #expect(StatusVocabulary.enrolment("WITHDRAWN").kind == .danger)
        #expect(StatusVocabulary.enrolment("INVALIDATED").kind == .danger)
    }

    // MARK: - Convocatoria

    @Test func convocatoriaStatesReadAsSpanish() {
        #expect(StatusVocabulary.convocatoria("OPEN").label == "Abierta")
        #expect(StatusVocabulary.convocatoria("CLOSING").label == "En cierre")
        #expect(StatusVocabulary.convocatoria("CLOSED").label == "Cerrada")
        #expect(StatusVocabulary.convocatoria("LOCKED").label == "Definitiva")
        #expect(StatusVocabulary.convocatoria("PREVIEW").label == "Previa")
        #expect(StatusVocabulary.convocatoria("DRAFT").label == "Borrador")
        #expect(StatusVocabulary.convocatoria("ARCHIVED").label == "Archivada")
    }

    /// `CLOSED` and `LOCKED` are not the same thing — the first still has the
    /// 24 h revocation window open, the second does not. `GradeFinality` draws
    /// that line, and collapsing the two labels here would contradict it on the
    /// very same screen.
    @Test func closedAndLockedStayDistinct() {
        #expect(StatusVocabulary.convocatoria("CLOSED").label != StatusVocabulary.convocatoria("LOCKED").label)
        #expect(GradeFinality(convocatoriaStatus: "CLOSED") == .pendingConfirmation)
        #expect(GradeFinality(convocatoriaStatus: "LOCKED") == .definitive)
    }

    // MARK: - What the app does not know

    /// The rule that matters: a state this build has never seen is shown
    /// verbatim, not swallowed and not guessed. A new backend state reaching a
    /// screen as its raw code is recoverable; the app silently deciding it
    /// means "Activa" is not.
    @Test func unknownStatesAreShownVerbatim() {
        #expect(StatusVocabulary.convocatoria("SUSPENDED_BY_TRIBUNAL").label == "SUSPENDED_BY_TRIBUNAL")
        #expect(StatusVocabulary.enrolment("APPEAL_PENDING").label == "APPEAL_PENDING")
        #expect(StatusVocabulary.convocatoria("SUSPENDED_BY_TRIBUNAL").kind == .neutral)
    }

    /// Absent is the one case with nothing to print: an empty capsule says less
    /// than saying there is no state.
    @Test func absentStateSaysSo() {
        #expect(StatusVocabulary.enrolment(nil).label == "Sin estado")
        #expect(StatusVocabulary.convocatoria("").label == "Sin estado")
        #expect(StatusVocabulary.convocatoria("   ").label == "Sin estado")
    }

    // MARK: - Rol

    /// The profile badge and the «Rol» row rendered the raw backend enum, so a
    /// firefighter read «Student» and «STUDENT» in an interface that addresses
    /// them formally in Castilian everywhere else. The portal says «Aspirante».
    @Test func rolesReadAsSpanish() {
        #expect(StatusVocabulary.role("STUDENT") == "Aspirante")
        #expect(StatusVocabulary.role("MANAGER") == "Instructor")
        #expect(StatusVocabulary.role("ADMIN") == "Administración")
        #expect(StatusVocabulary.role("SUPER_ADMIN") == "Administración")
    }

    @Test func roleToleratesCasingAndWhitespace() {
        #expect(StatusVocabulary.role("student") == "Aspirante")
        #expect(StatusVocabulary.role("  Manager  ") == "Instructor")
    }

    /// Same rule as the status badges: a role this version does not know is shown
    /// literally rather than swallowed or renamed. Seeing a code is
    /// recoverable; seeing nothing is not.
    @Test func anUnknownRoleIsShownAsItArrives() {
        #expect(StatusVocabulary.role("OBSERVER") == "OBSERVER")
        #expect(StatusVocabulary.role("") == "Sin rol")
        #expect(StatusVocabulary.role(nil) == "Sin rol")
    }

    /// GDPR art. 22: a status badge reports where the process stands, never
    /// how the candidate did.
    @Test func noLabelStatesAnOutcome() {
        let states = ["ACTIVE", "WITHDRAWN", "INVALIDATED", "OPEN", "CLOSING",
                      "CLOSED", "LOCKED", "PREVIEW", "DRAFT", "ARCHIVED", nil]
        let roles = ["STUDENT", "MANAGER", "ADMIN", "SUPER_ADMIN", "OBSERVER", nil]
        let banned = ["apto", "suspens", "aprob", "corte", "plaza", "cupo"]

        var labels = roles.map { StatusVocabulary.role($0) }
        for state in states {
            labels.append(StatusVocabulary.enrolment(state).label)
            labels.append(StatusVocabulary.convocatoria(state).label)
        }

        for label in labels {
            for word in banned {
                #expect(!label.lowercased().contains(word), "«\(word)» en «\(label)»")
            }
        }
    }
}
