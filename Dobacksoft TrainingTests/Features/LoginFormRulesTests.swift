import Testing
import Foundation

@testable import Dobacksoft_Training

/// When the login form may be submitted, and what Return does in each field.
///
/// This is the first screen every candidate sees and the least cared for: there
/// was no focus chain and no `onSubmit`, so Return did nothing in either field
/// and anyone with a hardware keyboard — every iPad with a case — had to reach
/// for the button.
///
/// The rules live outside the view so they can be tested: «cuándo se puede
/// enviar» is the kind of condition that grows an `||` in a hurry and nobody
/// notices it now enables a submit with an empty password.
struct LoginFormRulesTests {
    // MARK: - Cuándo se puede enviar

    @Test func anEmptyFormCannotBeSubmitted() {
        #expect(LoginFormRules.canSubmit(email: "", password: "") == false)
    }

    @Test func eitherFieldAloneIsNotEnough() {
        #expect(LoginFormRules.canSubmit(email: "a@b.example", password: "") == false)
        #expect(LoginFormRules.canSubmit(email: "", password: "secreto") == false)
    }

    @Test func bothFieldsFilledCanBeSubmitted() {
        #expect(LoginFormRules.canSubmit(email: "a@b.example", password: "secreto"))
    }

    /// A field with only spaces is empty. Someone who leans on the space bar
    /// should not be able to spend an attempt.
    @Test func whitespaceAloneIsAnEmptyField() {
        #expect(LoginFormRules.canSubmit(email: "   ", password: "secreto") == false)
        #expect(LoginFormRules.canSubmit(email: "a@b.example", password: "   ") == false)
    }

    /// **The password is never trimmed.** A password may legitimately begin or
    /// end with a space, and silently altering what someone typed would reject
    /// a correct password with no explanation. Only the emptiness check ignores
    /// whitespace; what gets SENT is what was typed.
    @Test func theSentPasswordIsExactlyWhatWasTyped() {
        #expect(LoginFormRules.password(from: " secreto ") == " secreto ")
        #expect(LoginFormRules.canSubmit(email: "a@b.example", password: " s "))
    }

    /// The email IS trimmed: a trailing space from an autocomplete or a paste
    /// is a typo, never part of an address, and it would fail the login with a
    /// message about credentials.
    @Test func theEmailIsTrimmedBecauseASpaceIsNeverPartOfIt() {
        #expect(LoginFormRules.email(from: "  a@b.example  ") == "a@b.example")
    }

    /// What the client does NOT do: judge whether the address is valid. A
    /// regular expression that rejects a real address locks someone out of
    /// their own account, and the server is the one that knows.
    @Test func theClientNeverJudgesWhetherTheAddressIsValid() {
        for raro in ["sin-arroba", "a@b", "a@@b.example", "ñ@dominio.example"] {
            #expect(LoginFormRules.canSubmit(email: raro, password: "secreto"),
                    "«\(raro)» lo decide el servidor, no el formulario")
        }
    }

    // MARK: - Qué hace Return en cada campo

    /// Return on the email moves to the password; on the password it submits.
    /// That is the whole point: a hardware keyboard should finish the login
    /// without touching the screen.
    @Test func returnMovesForwardAndThenSubmits() {
        #expect(LoginFormRules.nextField(after: .email) == .password)
        #expect(LoginFormRules.nextField(after: .password) == nil, "el último envía, no avanza")
    }

    /// And it does not submit from the password when the form is not ready:
    /// pressing Return with an empty email would spend one of the five attempts
    /// per minute on nothing.
    @Test func returnOnTheLastFieldDoesNotSubmitAnIncompleteForm() {
        #expect(LoginFormRules.submitsOnReturn(from: .password, email: "a@b.example", password: "x"))
        #expect(LoginFormRules.submitsOnReturn(from: .password, email: "", password: "x") == false)
        #expect(LoginFormRules.submitsOnReturn(from: .email, email: "a@b.example", password: "x") == false,
                "desde el email se avanza, no se envía")
    }
}
