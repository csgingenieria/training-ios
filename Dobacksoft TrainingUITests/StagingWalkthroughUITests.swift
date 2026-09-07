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

    /// Drills into the richest screen the app has: one attempt's detail, with
    /// its event list and score breakdown.
    ///
    /// This is where a real payload differs most from a fixture. The live
    /// server sends breakdown rows in states the fixtures never carried, and
    /// event timestamps already formatted as wall-clock strings rather than
    /// ISO instants. Neither is visible from a decode test.
    ///
    /// Skips rather than fails when the account has no attempt yet: an empty
    /// convocatoria is a legitimate state, not a defect.
    func testAttemptDetail() throws {
        let app = XCUIApplication()
        app.launch()

        try signIn(app)
        dismissSystemSavePasswordSheet()

        // Addressed by label, not by index: the tab set differs by role, and
        // `boundBy: 1` landed on Convocatorias for a STUDENT session — the test
        // then screenshotted the wrong screen and skipped without saying so.
        let standing = app.tabBars.buttons["Mi posición"]
        guard standing.waitForExistence(timeout: 10) else {
            throw XCTSkip("This role has no standing tab; attempts are reached elsewhere.")
        }
        // The floating tab bar swallows the first tap when the app opens
        // straight into a restored session, so one tap is not enough to prove
        // anything either way. Retry, then fail with the screen attached.
        guard select(standing, attempts: 3) else {
            capture(app, named: "09-pestana-no-seleccionada")
            return XCTFail("«Mi posición» would not select after 3 taps. See the attached screenshot.")
        }

        // The attempt rows sit below the fold on every device this ships to.
        app.swipeUp()
        app.swipeUp()
        capture(app, named: "10-mis-intentos")

        // Addressed by identifier. Matching on the row's own text was a guess
        // about copy, and "everything tappable that is not a tab" picked the
        // sort menu — also a button — and reported the failure as the detail
        // screen not opening.
        let attempt = app.buttons.matching(identifier: "standing.attempt").firstMatch
        guard attempt.waitForExistence(timeout: 5) else {
            throw XCTSkip("This account has no recorded attempt to open.")
        }

        attempt.tap()
        // Navigation is proven by leaving the tab, not by the tap returning.
        XCTAssertTrue(
            app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 10),
            "Tapping «\(attempt.label)» did not push a detail screen."
        )
        capture(app, named: "11-detalle-intento")

        assertNoDecodingFailureVisible(app, screen: "Detalle del intento")
        assertNoVerdictVisible(app, screen: "Detalle del intento")
        assertNoUnexplainedBreakdownRow(app)
    }

    /// A breakdown row that could not be measured must say why.
    ///
    /// «No evaluado» on its own reads as a zero the candidate scored in a
    /// component the panel actually set aside. The contract sends the reason;
    /// the app failed to translate the one state the backend sends most —
    /// `no_medido` — and the row went silent. Fixtures could not catch it,
    /// because they were written from the same reading of the contract as the
    /// code they were checking.
    private func assertNoUnexplainedBreakdownRow(_ app: XCUIApplication) {
        let labels = app.staticTexts.allElementsBoundByIndex
            .prefix(300)
            .compactMap { $0.exists ? $0.label : nil }

        guard labels.contains(where: { $0 == "No evaluado" || $0 == "Sin dato" }) else { return }

        // The explanation renders as its own text next to the label, so the
        // screen must carry more than the bare two words.
        let explanations = labels.filter { $0.count > 25 && $0.last == "." }
        XCTAssertFalse(
            explanations.isEmpty,
            "Una fila del desglose dice «No evaluado» sin explicar por qué."
        )
    }

    // MARK: - Steps

    private func signIn(_ app: XCUIApplication) throws {
        // The session lives in the Keychain, which survives between runs, so
        // the app often opens already signed in. A test that only works on a
        // clean Keychain fails on its own second run.
        if app.tabBars.firstMatch.waitForExistence(timeout: 5) { return }

        let email = app.textFields["login.email"]
        XCTAssertTrue(
            email.waitForExistence(timeout: 10),
            "Neither a session nor a login screen — the app opened on something else."
        )

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

    /// Taps a tab until it reports selected, or gives up.
    private func select(_ tab: XCUIElement, attempts: Int) -> Bool {
        for _ in 0..<attempts {
            tab.tap()
            if waitUntilSelected(tab, timeout: 4) { return true }
        }
        return false
    }

    /// Waits on an NSPredicate rather than polling `isSelected` in a loop.
    ///
    /// The loop version span without yielding, so XCUITest never refreshed its
    /// snapshot of the app and the property stayed at whatever it read first.
    /// `XCTNSPredicateExpectation` re-queries the app on each evaluation.
    private func waitUntilSelected(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"),
            object: element
        )
        return XCTWaiter.wait(for: [selected], timeout: timeout) == .completed
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
