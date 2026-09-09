import Testing
import Foundation

@testable import Dobacksoft_Training

/// How the server's state is shown in the profile.
///
/// The row put the whole error sentence in its value column — «No se ha podido
/// conectar. Compruebe su conexión a la red.» in the slot where «Disponible»
/// fits — and there was no way to ask again.
struct ServerHealthPresentationTests {
    /// **The value column stays short whatever happened.** That is the defect:
    /// a full sentence in a `LabeledContent` value wraps over the label and the
    /// row stops being readable.
    @Test func theValueIsAlwaysShort() {
        let estados: [ServerHealthPresentation] = [
            .checking,
            .available("ok · 1.4.2"),
            .unavailable("No se ha podido conectar. Compruebe su conexión a la red.")
        ]
        for estado in estados {
            #expect(estado.value.count <= 14, "«\(estado.value)» no cabe en una columna de valor")
        }
    }

    /// And the sentence is not lost — it moves to the footer, where a sentence
    /// fits.
    @Test func theSentenceMovesToTheFooter() {
        let estado = ServerHealthPresentation.unavailable("No se ha podido conectar.")
        #expect(estado.value == "No disponible")
        #expect(estado.footer == "No se ha podido conectar.")
    }

    /// A reachable server reports its version: it is the datum that says
    /// whether app and backend are in step when something does not add up.
    @Test func areachableServerReportsItsVersion() {
        let estado = ServerHealthPresentation.from(.success(HealthDTO(status: "ok", version: "1.4.2", time: "2026-09-09T00:00:00Z")))
        #expect(estado.value == "Disponible")
        #expect(estado.footer == "ok · 1.4.2")
    }

    /// A transport failure is «No disponible» with its own sentence, never the
    /// raw error type.
    @Test func atransportFailureSaysWhatHappened() {
        let estado = ServerHealthPresentation.from(
            .failure(APIError.transport(URLError(.notConnectedToInternet)))
        )
        #expect(estado.value == "No disponible")
        #expect(estado.footer?.contains("conexión") == true)
    }

    /// While checking there is no footer and no re-check offered: two requests
    /// at once clarify nothing.
    @Test func whileCheckingNothingIsOfferedOrClaimed() {
        #expect(ServerHealthPresentation.checking.footer == nil)
        #expect(ServerHealthPresentation.checking.canRecheck == false)
        #expect(ServerHealthPresentation.available("x").canRecheck)
        #expect(ServerHealthPresentation.unavailable("x").canRecheck)
    }

    /// An empty detail is no footer, not an empty one: a blank line under the
    /// section reads as something missing.
    @Test func anEmptyDetailIsNoFooter() {
        #expect(ServerHealthPresentation.available("").footer == nil)
        #expect(ServerHealthPresentation.from(.success(HealthDTO(status: "", version: "", time: ""))).footer == nil)
    }
}
