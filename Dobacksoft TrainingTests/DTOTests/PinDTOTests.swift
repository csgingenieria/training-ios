import Testing
import Foundation

@testable import Dobacksoft_Training

/// `GET /api/v1/me/pin` — the candidate's own tablet PIN, block F.
///
/// It exists so nobody has to depend on someone else dictating it to them.
///
/// Two things make this contract careful, and both are in the tests:
///
/// - `pin` is `null` in TWO cases that are the same for the caller: there is no
///   PIN, or the encryption key is unavailable. Either way the screen says «no
///   se puede mostrar» and does NOT tell the candidate they cannot drive — the
///   hash is what validates the login, and it still works.
/// - The PIN alone opens nothing: the tablet asks for PIN **and** enrolment
///   number. A screen showing one without the other has not finished the job.
struct PinDTOTests {
    private func decode(_ json: String) throws -> PinDTO {
        try JSONDecoder().decode(PinDTO.self, from: Data(json.utf8))
    }

    @Test func aPinWithItsEnrolmentsDecodes() throws {
        let p = try decode(#"""
        {"pin": "4821", "activeEnrollments": [
          {"convocatoriaId": "c-1", "name": "Oposición 2026", "plaza": "118"}]}
        """#)

        #expect(p.pin == "4821")
        #expect(p.activeEnrollments.count == 1)
        #expect(p.activeEnrollments.first?.plaza == "118")
        #expect(p.canBeShown)
    }

    // MARK: - El doble significado del nulo

    /// Neither case is «you cannot drive». The hash validates the login and it
    /// still works, so saying otherwise would send a candidate home for a
    /// display problem.
    @Test func aMissingPinDoesNotMeanTheCandidateCannotDrive() throws {
        let p = try decode(#"{"pin": null, "activeEnrollments": [{"convocatoriaId": "c-1", "plaza": "118"}]}"#)

        #expect(p.canBeShown == false)
        #expect(p.blocksDriving == false, "el hash sigue validando el acceso")
    }

    /// The sentinel, again: the portal formats for Jinja, so an unavailable PIN
    /// can arrive as «—» rather than as `null`. It is the same absence.
    @Test func theSentinelIsNotAPin() throws {
        for vacio in [#""—""#, #""  ""#, #""""#] {
            let p = try decode(#"{"pin": \#(vacio), "activeEnrollments": []}"#)
            #expect(p.pin == nil, "«\(vacio)» no es un PIN")
            #expect(p.canBeShown == false)
        }
    }

    // MARK: - El PIN solo no abre nada

    /// The tablet asks for both, so a PIN with no enrolment number is half an
    /// answer and the screen has to know it.
    @Test func aPinWithoutAnEnrolmentNumberIsHalfAnAnswer() throws {
        let p = try decode(#"{"pin": "4821", "activeEnrollments": []}"#)

        #expect(p.canBeShown)
        #expect(p.isReadyForTheTablet == false, "la tablet pide PIN y número de inscripción")
    }

    @Test func aPinWithAnEnrolmentNumberIsReady() throws {
        let p = try decode(#"{"pin": "4821", "activeEnrollments": [{"convocatoriaId": "c-1", "plaza": "118"}]}"#)

        #expect(p.isReadyForTheTablet)
    }

    /// An enrolment with no `plaza` does not complete it either: the number is
    /// what the tablet asks for, not the convocatoria's name.
    @Test func anEnrolmentWithoutItsNumberDoesNotCompleteIt() throws {
        let p = try decode(#"{"pin": "4821", "activeEnrollments": [{"convocatoriaId": "c-1", "name": "Oposición"}]}"#)

        #expect(p.isReadyForTheTablet == false)
    }

    // MARK: - Vocabulario

    /// The web passes this list as `plazas=` — quota vocabulary, forbidden by
    /// article 22. The JSON uses `activeEnrollments`, and the client must not
    /// reintroduce the old name anywhere.
    @Test func theListIsNotCalledByTheForbiddenName() throws {
        // `plazas` no existe como clave: si el backend la reintrodujera, esto
        // seguiría decodificando y la lista saldría vacía, que es lo que se
        // quiere — nunca un rótulo de cupo en la pantalla.
        let p = try decode(#"{"pin": "4821", "plazas": [{"plaza": "118"}]}"#)

        #expect(p.activeEnrollments.isEmpty)
    }

    @Test func anOlderServerWithoutTheFieldsClaimsNothing() throws {
        let p = try decode("{}")

        #expect(p.pin == nil)
        #expect(p.activeEnrollments.isEmpty)
        #expect(p.blocksDriving == false)
    }
}

/// What the PIN screen says.
///
/// The whole screen exists for the moment before driving, so every sentence has
/// to be usable then: «no se puede mostrar» has to make clear that the
/// candidate can still drive, because the opposite reading sends them home.
struct PinCopyTests {
    @Test func theUnavailableMessageDoesNotSayTheCandidateCannotDrive() {
        let copy = PinCopy.unavailable.lowercased()

        #expect(copy.contains("no puede conducir") == false)
        #expect(copy.contains("no podrá") == false)
        #expect(copy.contains("instructor"), "quien lo resuelve tiene que estar en la frase")
    }

    /// Why both numbers are on screen: the tablet asks for the two, and a
    /// candidate who only memorises the PIN gets stuck at the truck.
    @Test func theInstructionsNameBothNumbers() {
        let copy = PinCopy.tabletNeedsBoth

        #expect(copy.contains("PIN"))
        #expect(copy.contains("inscripción"))
    }

    /// Never the quota word, in any of the three sentences.
    @Test func noSentenceUsesQuotaVocabulary() {
        for copy in [PinCopy.unavailable, PinCopy.tabletNeedsBoth, PinCopy.keepItPrivate] {
            for prohibido in ["plazas", "cupo", "adjudica"] {
                #expect(copy.lowercased().contains(prohibido) == false, "«\(prohibido)» en «\(copy)»")
            }
        }
    }

    /// The PIN plus the enrolment number lets someone drive in your name, and
    /// the screen owes the candidate that warning without dramatising it.
    @Test func thePrivacyNoteSaysWhyItMatters() {
        #expect(PinCopy.keepItPrivate.contains("en su nombre"))
    }
}
