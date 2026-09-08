import Testing
import Foundation

@testable import Dobacksoft_Training

/// `GET /api/v1/me/card` — with which card the candidate is going to drive.
///
/// It is only text: the client never reads the chip. The use case is standing
/// in front of the truck and checking that the plastic in your pocket is the
/// one the system expects — and, if you have none, finding out before you get
/// there, because without a card no attempt can be opened.
///
/// `hasCard` is what closes that use case: it answers «can I drive today?»
/// without requiring the candidate to read a UID off a screen and compare it
/// character by character.
struct CardDTOTests {
    private func decode(_ json: String) throws -> CardDTO {
        try JSONDecoder().decode(CardDTO.self, from: Data(json.utf8))
    }

    @Test func aCardDecodesWhole() throws {
        let card = try decode(#"{"hasCard": true, "cardUid": "04A1B2C3D4", "webfleetDriverNo": "118"}"#)

        #expect(card.hasCard == true)
        #expect(card.cardUid == "04A1B2C3D4")
        #expect(card.webfleetDriverNo == "118")
    }

    // MARK: - Sin tarjeta, que es el caso que importa

    /// Having no card is not an error and not a blank screen: it is the one
    /// answer that has to reach the candidate BEFORE the day of the test.
    @Test func havingNoCardIsAnAnswerAndNotAnAbsence() throws {
        let card = try decode(#"{"hasCard": false, "cardUid": null, "webfleetDriverNo": null}"#)

        #expect(card.hasCard == false)
        #expect(card.cardUid == nil)
        #expect(card.canDriveToday == false)
        #expect(card.needsInstructor, "sin tarjeta hay que avisar, y antes de llegar al camión")
    }

    @Test func aCardMeansTheCandidateCanDrive() throws {
        let card = try decode(#"{"hasCard": true, "cardUid": "04A1B2C3D4"}"#)

        #expect(card.canDriveToday)
        #expect(card.needsInstructor == false)
    }

    /// `hasCard: true` with no UID is a contradiction the client must not
    /// resolve in the optimistic direction: the screen cannot offer a
    /// comparison it has no number for, so it stops claiming the candidate is
    /// ready.
    @Test func aCardWithoutItsNumberDoesNotClaimReadiness() throws {
        let card = try decode(#"{"hasCard": true, "cardUid": null}"#)

        #expect(card.canDriveToday == false, "sin número no hay nada que comparar delante del camión")
        #expect(card.needsInstructor)
    }

    /// The sentinel again: the portal formats for Jinja, so an empty UID can
    /// arrive as `"—"` or as blank. Neither is a card.
    @Test func theSentinelIsNotACardNumber() throws {
        for vacio in [#""—""#, #""  ""#, #""""#] {
            let card = try decode(#"{"hasCard": true, "cardUid": \#(vacio)}"#)
            #expect(card.cardUid == nil, "«\(vacio)» no es un número de tarjeta")
            #expect(card.canDriveToday == false)
        }
    }

    @Test func anOlderServerWithoutTheFieldsClaimsNothing() throws {
        let card = try decode("{}")

        #expect(card.hasCard == nil)
        #expect(card.canDriveToday == false)
        // Y tampoco afirma lo contrario: no se sabe, así que no se manda a
        // nadie a hablar con su instructor por un campo que no llegó.
        #expect(card.needsInstructor == false)
    }

    // MARK: - Webfleet driver

    /// Two different identifiers of the same person, and the screen must not
    /// merge them: the plastic carries the UID, the fleet knows the driver
    /// number, and comparing the wrong one against the card proves nothing.
    @Test func theDriverNumberIsNotTheCardNumber() throws {
        let card = try decode(#"{"hasCard": true, "cardUid": "04A1B2C3D4", "webfleetDriverNo": "118"}"#)

        #expect(card.cardUid != card.webfleetDriverNo)
    }

    @Test func aCandidateWithoutAFleetDriverNumberStillHasACard() throws {
        let card = try decode(#"{"hasCard": true, "cardUid": "04A1B2C3D4", "webfleetDriverNo": null}"#)

        #expect(card.canDriveToday, "la tarjeta es lo que abre el intento")
        #expect(card.webfleetDriverNo == nil)
    }
}

/// What the card section says, which is where the decision lives.
///
/// The screen exists for one moment: before the test, not during it. So the
/// copy has to be actionable at that moment — «no tiene tarjeta» alone leaves
/// the candidate with a problem they cannot solve on their own.
struct MyCardCopyTests {
    /// The exit has to be in the sentence: a candidate cannot assign themselves
    /// a card, so telling them it is missing without telling them who fixes it
    /// is an alarm and not information.
    @Test func theMissingCardMessageNamesTheWayOut() {
        let copy = MyCardCopy.noCard

        #expect(copy.contains("instructor"), "«\(copy)» no dice quién lo resuelve")
        #expect(copy.contains("antes"), "y tiene que decir que es antes de la prueba")
    }

    /// The consequence, not just the fact: without a card no attempt can be
    /// opened, and that is why it matters today rather than on the day.
    @Test func theMissingCardMessageSaysWhyItMatters() {
        #expect(MyCardCopy.noCard.contains("no se puede abrir un intento"))
    }

    /// «No se pudo preguntar» must not read as «no tiene»: those are opposite
    /// instructions for the candidate.
    @Test func theUnavailableMessageDoesNotClaimTheCardIsMissing() {
        let copy = MyCardCopy.unavailable.lowercased()

        #expect(copy.contains("no tiene") == false, "afirmaría una ausencia que no consta")
        #expect(copy.contains("instructor") == false, "no se manda a nadie por un dato que falta")
    }

    /// The footer tells the candidate what to DO with the number, which is the
    /// whole reason the screen shows a UID at all.
    @Test func theFooterAsksForTheComparisonThatJustifiesTheScreen() {
        let copy = MyCardCopy.compareWithThePlastic

        #expect(copy.contains("impreso"), "la comparación es contra el plástico")
        #expect(copy.contains("antes del día de la prueba"))
    }

    /// Formal Castilian throughout: these three reach a firefighter reading an
    /// official process.
    @Test func theThreeMessagesAddressTheReaderFormally() {
        for copy in [MyCardCopy.noCard, MyCardCopy.unavailable, MyCardCopy.compareWithThePlastic] {
            for tuteo in ["comprueba ", "avisa ", "vuelve ", " tu ", " tus "] {
                #expect(copy.lowercased().contains(tuteo) == false, "«\(tuteo)» en «\(copy)»")
            }
        }
    }
}
