import Testing
import Foundation

@testable import Dobacksoft_Training

/// When the app must cover what it is showing.
///
/// The widget is privacy-first — off by default citing GDPR art. 25.2, figures
/// marked `.privacySensitive()` — and the app opened straight onto the position
/// and the mark, with the app-switcher thumbnail showing the standing card.
struct PrivacyGateTests {
    /// **`.inactive` counts**, and that is the whole point.
    ///
    /// The system takes the app-switcher thumbnail at `.inactive`. Waiting for
    /// `.background` would capture it with the figures still on screen, which
    /// is precisely the frame that gets shown to whoever picks up the phone.
    @Test func inactiveIsAlreadyTooLateToWait() {
        #expect(PrivacyGate.shouldCover(phase: .inactive))
    }

    @Test func backgroundIsCovered() {
        #expect(PrivacyGate.shouldCover(phase: .background))
    }

    /// And active is not: covering the app while someone is using it would be
    /// a very effective privacy feature and a useless app.
    @Test func activeIsNotCovered() {
        #expect(!PrivacyGate.shouldCover(phase: .active))
    }
}
