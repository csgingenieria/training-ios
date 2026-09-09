import Testing
import Foundation

@testable import Dobacksoft_Training

/// When the app admits the network is being slow.
///
/// With a fifteen-second timeout, a screen could spin for fifteen seconds with
/// nothing saying whether anything was coming. A spinner means «wait»; after
/// four seconds it means «this is not working».
struct SlowNetworkHintTests {
    /// Four seconds, pinned. Below that it is an ordinary load and the notice
    /// would be noise on every screen opening.
    @Test func theThresholdIsFourSeconds() {
        #expect(SlowNetworkHint.threshold == 4)
    }

    /// It is well inside the request timeout: a hint that arrived after the
    /// request had already given up would say «be patient» about something
    /// that had stopped.
    @Test func theHintArrivesWellBeforeTheRequestGivesUp() {
        #expect(SlowNetworkHint.threshold < 15)
    }

    /// It says what to check, like every other message in the app.
    @Test func theHintSaysWhatToCheck() {
        #expect(SlowNetworkHint.message.contains("Compruebe"))
        #expect(SlowNetworkHint.message.contains("conexión"))
    }

    /// And it does not blame the person or claim a failure that has not
    /// happened: the request may still succeed.
    @Test func theHintClaimsNoFailureYet() {
        let mensaje = SlowNetworkHint.message.lowercased()
        #expect(!mensaje.contains("error"))
        #expect(!mensaje.contains("no se ha podido"))
        #expect(!mensaje.contains("fallo"))
    }
}
