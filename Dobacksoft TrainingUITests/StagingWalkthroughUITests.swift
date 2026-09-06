import XCTest

/// Signs in against a live backend and captures one screenshot per screen.
///
/// Why this exists: every automated check in this project runs against
/// fixtures this codebase wrote itself, so a payload the server actually sends
/// — or a screen the server's real data actually produces — was never
/// exercised. Reading the JSON with `curl` proves the DTOs decode; it does not
/// prove the screens render something a firefighter can act on. This does.
///
/// Credentials never live in the repository. Pass them through the
/// environment; `xcodebuild` forwards any `TEST_RUNNER_`-prefixed variable to
/// the test runner with the prefix stripped:
///
/// ```
/// TEST_RUNNER_STAGING_EMAIL=… TEST_RUNNER_STAGING_PASSWORD=… \
///   xcodebuild test -project "Dobacksoft Training.xcodeproj" \
///     -scheme "Dobacksoft Training" \
///     -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
///     -only-testing:"Dobacksoft TrainingUITests/StagingWalkthroughUITests"
/// ```
///
/// Without those variables every test here skips, so the suite stays green on
/// a machine with no backend access.
@MainActor
final class StagingWalkthroughUITests: XCTestCase {
    private var credentials: (email: String, password: String)!

    override func setUpWithError() throws {
        continueAfterFailure = false

        let env = ProcessInfo.processInfo.environment
        guard let email = env["STAGING_EMAIL"], !email.isEmpty,
              let password = env["STAGING_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_STAGING_EMAIL and TEST_RUNNER_STAGING_PASSWORD to run the live walkthrough.")
        }
        credentials = (email, password)
    }

    /// Walks every tab the signed-in account can reach and attaches what it saw.
    ///
    /// The tabs are read off the live tab bar rather than hardcoded. The first
    /// version of this test named them, which meant a STUDENT session — whose
    /// middle tab is "Mi posición", not "Panel" — silently skipped its single
    /// most important screen and still reported success.
    ///
    /// It asserts only on things that would be wrong for *any* account: that
    /// the session opened, that every tab was actually reached, that no screen
    /// shows a raw decoding failure, and that nothing on screen implies a
    /// verdict. Everything account-specific is left to the attached
    /// screenshots, because staging's data changes and a test that pinned it
    /// would fail for the wrong reason.
    func testSignedInWalkthrough() throws {
        let app = XCUIApplication()
        app.launch()

        try signIn(app)
        dismissSystemSavePasswordSheet()

        let tabs = app.tabBars.firstMatch.buttons.allElementsBoundByIndex.map(\.label)
        XCTAssertGreaterThanOrEqual(tabs.count, 2, "A signed-in session should expose more than one tab.")

        for (index, tab) in tabs.enumerated() {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "The «\(tab)» tab vanished mid-walkthrough.")
            button.tap()

            // A tap that lands on a system alert leaves the tab unselected, and
            // the walkthrough would then screenshot the same screen N times and
            // still pass. Selection is the proof that navigation happened.
            XCTAssertTrue(
                waitUntilSelected(button),
                "Tapping «\(tab)» did not select it — something is covering the screen."
            )

            capture(app, named: String(format: "%02d-%@", index + 1, slug(tab)))
            assertNoDecodingFailureVisible(app, screen: tab)
            assertNoVerdictVisible(app, screen: tab)
        }
    }

    // MARK: - Steps

    private func signIn(_ app: XCUIApplication) throws {
        let email = app.textFields["login.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10), "The login screen never appeared.")

        email.tap()
        email.typeText(credentials.email)

        let password = app.secureTextFields["login.password"]
        password.tap()
        password.typeText(credentials.password)

        app.buttons["login.submit"].tap()

        // The tab bar only exists once a session is open, so its arrival is the
        // signal that the round trip succeeded.
        guard app.tabBars.firstMatch.waitForExistence(timeout: 30) else {
            capture(app, named: "00-login-fallido")
            return XCTFail("No session after 30 s. See the attached screenshot for what the screen said.")
        }
    }

    /// iOS offers to save the password into the keychain right after a
    /// successful sign-in, and that sheet belongs to Springboard, not to this
    /// app — it swallows every tap underneath it while the app's own elements
    /// still answer `exists`. Left alone it turns the whole walkthrough into a
    /// sequence of identical screenshots that passes.
    private func dismissSystemSavePasswordSheet() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Ahora no", "Not Now", "No ahora"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 3) {
                button.tap()
                return
            }
        }
    }

    // MARK: - Assertions that hold for any account

    /// A screen showing the generic decoding message means a DTO does not match
    /// what the server sent — the exact failure fixtures cannot catch.
    private func assertNoDecodingFailureVisible(_ app: XCUIApplication, screen: String) {
        let message = "La respuesta del servidor no tiene el formato esperado."
        XCTAssertFalse(
            app.staticTexts[message].exists,
            "«\(screen)» failed to decode a real response."
        )
    }

    /// GDPR art. 22: the app reports measurements, never an outcome. No screen
    /// may state or imply that a candidate passed, failed, or made a cut.
    private func assertNoVerdictVisible(_ app: XCUIApplication, screen: String) {
        let banned = ["APTO", "NO APTO", "SUSPENSO", "APROBADO", "NOTA DE CORTE", "PLAZA ASIGNADA"]
        let visible = app.staticTexts.allElementsBoundByIndex
            .prefix(200)                       // a longer list would slow the run without adding coverage
            .compactMap { $0.exists ? $0.label : nil }
            .joined(separator: " · ")
            .uppercased()

        for word in banned where visible.contains(word) {
            XCTFail("«\(word)» appears on «\(screen)». The app must not state an outcome.")
        }
    }

    // MARK: - Helpers

    private func waitUntilSelected(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.isSelected { return true }
            _ = element.waitForExistence(timeout: 0.2)
        }
        return element.isSelected
    }

    private func slug(_ label: String) -> String {
        label.folding(options: .diacriticInsensitive, locale: .init(identifier: "es_ES"))
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
