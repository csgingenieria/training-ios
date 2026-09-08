import Testing
import Foundation

@testable import Dobacksoft_Training

/// When the change-password form may be submitted, and what it says when the
/// server refuses.
///
/// The rules are checked locally for one reason only: to avoid burning one of
/// the five attempts per minute on a mistake the client could already see. The
/// server remains the authority — the client never decides that a password is
/// correct, only that it is not worth sending yet.
struct PasswordFormRulesTests {
    // MARK: - Cuándo se puede enviar

    @Test func anEmptyFormCannotBeSubmitted() {
        #expect(PasswordFormRules.canSubmit(current: "", new: "", confirm: "") == false)
    }

    @Test func aCompleteAndCoherentFormCanBeSubmitted() {
        #expect(PasswordFormRules.canSubmit(current: "vieja123", new: "nueva12345", confirm: "nueva12345"))
    }

    /// Two different new passwords is the one mistake the client can see with
    /// certainty, so it does not spend an attempt on it.
    @Test func mismatchedRepetitionIsCaughtBeforeSpendingAnAttempt() {
        #expect(PasswordFormRules.canSubmit(current: "vieja123", new: "nueva12345", confirm: "nueva54321") == false)
        #expect(PasswordFormRules.localProblem(new: "nueva12345", confirm: "nueva54321") == .doNotMatch)
    }

    /// The minimum length is the backend's, and knowing it locally saves an
    /// attempt too.
    @Test func aTooShortPasswordIsCaughtLocally() {
        #expect(PasswordFormRules.localProblem(new: "corta", confirm: "corta") == .tooShort)
        #expect(PasswordFormRules.canSubmit(current: "vieja123", new: "corta", confirm: "corta") == false)
    }

    /// What the client must NOT decide: whether the current password is right.
    /// Only the server knows, and guessing here would lock someone out of their
    /// own account over a client-side rule.
    @Test func theClientNeverJudgesTheCurrentPassword() {
        // Una contraseña actual «rara» se envía igual: no es asunto del cliente.
        #expect(PasswordFormRules.canSubmit(current: "a", new: "nueva12345", confirm: "nueva12345"))
        #expect(PasswordFormRules.localProblem(new: "nueva12345", confirm: "nueva12345") == nil)
    }

    /// Trailing spaces are not trimmed: a password may legitimately contain
    /// them, and silently altering what someone typed would make the form
    /// reject a correct password with no explanation.
    @Test func spacesAreNotStrippedFromWhatWasTyped() {
        #expect(PasswordFormRules.canSubmit(current: "vieja123", new: "con espacio ", confirm: "con espacio "))
        #expect(PasswordFormRules.canSubmit(current: "vieja123", new: "con espacio ", confirm: "con espacio") == false)
    }

    // MARK: - Lo que se dice cuando el servidor se niega

    /// Every error key the backend can send has a sentence. An unknown key
    /// falls back without showing the raw code.
    @Test func everyServerErrorHasACastilianSentence() {
        let claves = ["missing_fields", "wrong_current_password", "passwords_do_not_match",
                      "password_too_short", "password_unchanged", "user_not_found"]

        for clave in claves {
            let frase = PasswordFormRules.message(forServerError: clave)
            #expect(frase.isEmpty == false)
            #expect(frase.contains("_") == false, "«\(frase)» enseña el código crudo")
        }
    }

    @Test func anUnknownServerErrorDoesNotLeakItsCode() {
        let frase = PasswordFormRules.message(forServerError: "un_motivo_de_mañana")

        #expect(frase.contains("un_motivo_de_mañana") == false)
        #expect(frase.isEmpty == false)
    }

    /// «La contraseña actual no es correcta» must not read as «your account is
    /// broken»: it is a typo, and the form stays open.
    @Test func theWrongCurrentPasswordMessageDoesNotAlarm() {
        let frase = PasswordFormRules.message(forServerError: "wrong_current_password").lowercased()

        #expect(frase.contains("actual"))
        for alarma in ["bloquead", "error del sistema", "contacte"] {
            #expect(frase.contains(alarma) == false, "«\(alarma)» alarma de más")
        }
    }

    /// Reusing the same password is not a failure worth scolding: it is a
    /// no-op, and the sentence says so plainly.
    @Test func reusingTheSamePasswordIsStatedWithoutScolding() {
        let frase = PasswordFormRules.message(forServerError: "password_unchanged").lowercased()

        #expect(frase.contains("misma") || frase.contains("distinta"))
        #expect(frase.contains("debe ") == false)
    }

    /// Formal Castilian in all of them.
    @Test func theMessagesAddressTheReaderFormally() {
        for clave in ["missing_fields", "wrong_current_password", "password_too_short",
                      "password_unchanged", "desconocido"] {
            let frase = PasswordFormRules.message(forServerError: clave).lowercased()
            for tuteo in ["escribe ", "comprueba ", "vuelve ", " tu ", " tus "] {
                #expect(frase.contains(tuteo) == false, "«\(tuteo)» en «\(frase)»")
            }
        }
    }
}
