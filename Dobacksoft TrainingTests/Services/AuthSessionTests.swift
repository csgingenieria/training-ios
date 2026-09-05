import Testing
import Foundation

@testable import Dobacksoft_Training

/// Tests para AuthSession.
///
/// `AuthSession` is `@MainActor`-isolated, so the suite is too.
///
/// Scope is deliberately limited to state that does not depend on `APIClient`:
/// `isAuthenticated`, `logout`, the preview helper and role detection.
///
/// Not covered yet: `login()`, `restoreFromKeychain()` and refresh-on-401.
/// `APIClient` is a concrete `actor` with a `static let shared`, so the network
/// layer cannot be substituted. Those tests land once it is behind a protocol.
@MainActor
struct AuthSessionTests {
    @Test func initialSessionIsNotAuthenticated() {
        let session = AuthSession()
        #expect(session.isAuthenticated == false)
        #expect(session.hasRestoredSession == false)
        #expect(session.user == nil)
        #expect(session.accessToken == nil)
        #expect(session.refreshToken == nil)
    }

    @Test func previewSessionIsAuthenticated() {
        let session = AuthSession.previewAuthenticated
        #expect(session.isAuthenticated == true)
        #expect(session.hasRestoredSession == true)
        #expect(session.user != nil)
        #expect(session.accessToken == "preview")
        #expect(session.refreshToken == "preview")
    }

    @Test func logoutClearsState() async {
        let session = AuthSession.previewAuthenticated
        #expect(session.isAuthenticated == true)

        await session.logout()

        #expect(session.isAuthenticated == false)
        #expect(session.user == nil)
        #expect(session.accessToken == nil)
        #expect(session.refreshToken == nil)
        #expect(session.hasRestoredSession == true)
    }

    @Test func isStudentDetected() {
        let session = AuthSession.previewAuthenticated
        #expect(session.user?.isStudent == false) // preview es ADMIN
        #expect(session.user?.isAdminLike == true)
    }
}
