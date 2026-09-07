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
        let app = launchClean()

        try signIn(app)
        dismissSystemSavePasswordSheet()

        // Compact width gets a TabView and every destination is reachable.
        // Regular width gets a NavigationSplitView, and XCUITest cannot drive
        // a SwiftUI `List(selection:)` sidebar: six approaches — tapping the
        // static text, the containing cell, a normalized coordinate, and the
        // row with `.isButton` and its children combined — all left the detail
        // pane where it was. The app itself is fine; a person taps it and it
        // moves, and there are screenshots of every screen rendering on iPad.
        //
        // So on that layout this asserts what it honestly can — the session
        // opened, the landing screen decoded, nothing implies a verdict — and
        // says out loud what it cannot cover, instead of leaving a red test
        // that fails for a tooling limit and teaches everyone to ignore red.
        guard app.tabBars.firstMatch.exists else {
            capture(app, named: "01-sidebar")
            assertNoDecodingFailureVisible(app, screen: "Pantalla inicial")
            assertNoVerdictVisible(app, screen: "Pantalla inicial")

            let rows = destinations(in: app)
            XCTAssertGreaterThanOrEqual(
                rows.count, 2,
                "El sidebar no ofrece destinos: la sesión no llegó a abrirse."
            )
            throw XCTSkip(
                "Layout de sidebar: XCUITest no acciona la selección de un List de SwiftUI. "
                + "Verificado: sesión abierta y \(rows.count) destinos presentes (\(rows.joined(separator: ", "))). "
                + "SIN cubrir: la navegación a cada uno."
            )
        }

        let places = destinations(in: app)
        if places.count < 2 {
            capture(app, named: "00-sin-destinos")
            attachHierarchy(app)
            return XCTFail("Found \(places.count) destinations: \(places). See the attached hierarchy.")
        }

        for (index, destination) in places.enumerated() {
            // A tap that lands on a system alert changes nothing, and the
            // walkthrough would then screenshot the same screen N times and
            // still pass. Arrival is the proof that navigation happened.
            XCTAssertTrue(
                navigate(to: destination, in: app),
                "«\(destination)» never opened — something is covering the screen."
            )

            capture(app, named: String(format: "%02d-%@", index + 1, slug(destination)))
            assertNoDecodingFailureVisible(app, screen: destination)
            assertNoVerdictVisible(app, screen: destination)
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
        let app = launchClean()

        try signIn(app)
        dismissSystemSavePasswordSheet()

        // Addressed by label, not by index: the tab set differs by role, and
        // `boundBy: 1` landed on Convocatorias for a STUDENT session — the test
        // then screenshotted the wrong screen and skipped without saying so.
        guard destinations(in: app).contains("Mi posición") else {
            throw XCTSkip("This role has no standing screen; attempts are reached elsewhere.")
        }
        guard navigate(to: "Mi posición", in: app) else {
            capture(app, named: "09-sin-navegar")
            return XCTFail("«Mi posición» would not open. See the attached screenshot.")
        }

        // The attempt rows sit below the fold on every device this ships to.
        app.swipeUp()
        app.swipeUp()
        capture(app, named: "10-mis-intentos")

        // Addressed by identifier. Matching on the row's own text was a guess
        // about copy, and "everything tappable that is not a tab" picked the
        // sort menu — also a button — and reported the failure as the detail
        // screen not opening.
        let attempt = element("standing.attempt", in: app)
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

    /// Opens «Resultados» for the first convocatoria and captures the table.
    ///
    /// This is the screen that replaced «Ranking completo» and «Matriz de
    /// puntuaciones», and the one where the two sources are crossed: the
    /// columns are the union of the matrix's circuits and the convocatoria's
    /// required routes, because the matrix only returns circuits somebody has
    /// driven. On the real convocatoria that is five columns out of ten, and
    /// the five it omits are the ones that explain every grade.
    ///
    /// Only a MANAGER reaches it; a STUDENT gets 403 on both endpoints, so the
    /// test skips instead of failing on the wrong account.
    func testResultados() throws {
        let app = launchClean()

        try signIn(app)
        dismissSystemSavePasswordSheet()

        guard navigate(to: "Convocatorias", in: app) else {
            throw XCTSkip("No se pudo abrir «Convocatorias». En iPad es el límite de XCUITest con el sidebar, no la app.")
        }

        let row = element("convocatorias.row", in: app)
        guard row.waitForExistence(timeout: 10) else {
            // El árbol, no una conjetura: dos ejecuciones se perdieron
            // adivinando el tipo de elemento de una fila de lista.
            capture(app, named: "19-sin-fila")
            attachHierarchy(app)
            throw XCTSkip("No «convocatorias.row» on screen. See the attached hierarchy.")
        }
        row.tap()

        let resultados = app.buttons["Resultados"]
        guard resultados.waitForExistence(timeout: 10) else {
            throw XCTSkip("This role has no «Resultados» — it is instructor-only.")
        }
        resultados.tap()

        XCTAssertTrue(
            app.staticTexts["Aspirante"].waitForExistence(timeout: 20),
            "«Resultados» never rendered its table header."
        )
        capture(app, named: "20-resultados")

        assertNoDecodingFailureVisible(app, screen: "Resultados")
        assertNoVerdictVisible(app, screen: "Resultados")
    }

    // MARK: - Steps

    /// Launches with no session at all.
    ///
    /// Reusing whatever session the Keychain held was worse than useless: a run
    /// asking for the candidate's account opened inside the instructor's, found
    /// none of its screens and skipped green. Existing is not the same as being
    /// the right account, and the test cannot tell them apart from the outside.
    private func launchClean() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset-session"]
        app.launch()
        return app
    }

    private func signIn(_ app: XCUIApplication) throws {
        let email = app.textFields["login.email"]
        XCTAssertTrue(
            email.waitForExistence(timeout: 10),
            "Neither a session nor a login screen — the app opened on something else."
        )

        try type(credentials.email, into: email, in: app)
        try type(credentials.password, into: app.secureTextFields["login.password"], in: app)

        app.buttons["login.submit"].tap()

        // The signal is the login field going away, not a tab bar arriving.
        //
        // On iPad the app lays itself out as a sidebar and there IS no tab bar,
        // so waiting for one failed 30 s after a sign-in that had actually
        // worked — the dashboard was on screen behind the system sheet. Only
        // running on iPad showed it.
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: email
        )
        guard XCTWaiter.wait(for: [gone], timeout: 30) == .completed else {
            capture(app, named: "00-login-fallido")
            return XCTFail("No session after 30 s. See the attached screenshot for what the screen said.")
        }
    }

    /// Navigates to a top-level destination on either layout.
    ///
    /// iPhone gets a `TabView`; iPad regular width gets a `NavigationSplitView`
    /// whose sidebar is a `List(selection:)` of `Label`s — and those surface as
    /// **cells**, not buttons, so a button-only lookup found nothing and the
    /// walkthrough reported zero destinations on a session that had four.
    /// The label is the same on both, so it is the only part worth naming.
    private func navigate(to destination: String, in app: XCUIApplication) -> Bool {
        let tab = app.tabBars.buttons[destination]
        if tab.waitForExistence(timeout: 3) {
            // Dos pruebas de llegada, no una: la barra flotante se come toques
            // de forma intermitente y `isSelected` se quedaba en falso sobre
            // una pantalla que sí había abierto. Si cualquiera de las dos lo
            // confirma, ha navegado.
            if select(tab, attempts: 3) { return true }
            return app.navigationBars[destination].waitForExistence(timeout: 5)
        }

        guard let row = sidebarRow(destination, in: app) else { return false }

        // Un toque directo sobre la fila no mueve la selección del List, y un
        // toque sobre su texto tampoco. Por coordenada del centro sí.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        if app.navigationBars[destination].waitForExistence(timeout: 8) { return true }
        row.tap()

        // Arrival is the DETAIL pane's navigation bar, and nothing else.
        //
        // The previous version fell back to `app.staticTexts[destination]`,
        // which matched the sidebar row it had just tapped: the check passed
        // while the detail pane still showed «Panel», and the test then went
        // looking for a list row on the wrong screen and skipped, reporting it
        // as an account with no convocatoria.
        return app.navigationBars[destination].waitForExistence(timeout: 10)
    }

    /// The sidebar row for a destination.
    ///
    /// The row is a `Cell` with **no label of its own** — the text lives in a
    /// nested `StaticText`, so `cells[label]` matches nothing and tapping the
    /// text does not move the `List` selection either. The cell is what has to
    /// be tapped, and it is found by the text it contains. Scoped to the
    /// sidebar so it cannot collide with a navigation title of the same name.
    private func sidebarRow(_ destination: String, in app: XCUIApplication) -> XCUIElement? {
        let identifiers = [
            "Panel": "panel", "Convocatorias": "convocatorias",
            "Mi posición": "miPosicion", "Perfil": "perfil",
        ]
        if let key = identifiers[destination] {
            let row = element("sidebar.\(key)", in: app)
            if row.waitForExistence(timeout: 5) { return row }
        }

        let text = sidebar(app).staticTexts[destination]
        return text.waitForExistence(timeout: 3) ? text : nil
    }

    private func sidebar(_ app: XCUIApplication) -> XCUIElement {
        app.collectionViews["Sidebar"]
    }

    /// An element by identifier, whatever kind SwiftUI made of it.
    ///
    /// The same `NavigationLink` surfaces as a button on iPhone and as
    /// something else inside the split view's detail pane on iPad, so querying
    /// `app.buttons` skipped the whole test on iPad with a message that read
    /// like an empty account. Identifiers are stable; element kinds are not.
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The top-level destinations this session exposes, on either layout.
    private func destinations(in app: XCUIApplication) -> [String] {
        let tabs = app.tabBars.firstMatch.buttons.allElementsBoundByIndex.map(\.label)
        if !tabs.isEmpty { return tabs }

        // The sidebar's own rows, in the order the app declares them. «Inicio»
        // and «Cuenta» are section headers, not destinations, so they are not
        // in this list.
        return ["Panel", "Convocatorias", "Mi posición", "Perfil"]
            .filter { sidebar(app).staticTexts[$0].exists }
    }

    /// Taps a field, waits until it actually has the keyboard, and types.
    ///
    /// `tap()` followed straight by `typeText` failed intermittently with
    /// «Neither element nor any descendant has keyboard focus»: the tap lands
    /// before the field is ready to receive it. Passing alone and failing in a
    /// full run is the worst kind of test, so the wait is explicit.
    private func type(_ text: String, into field: XCUIElement, in app: XCUIApplication) throws {
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No apareció el campo \(field.identifier).")

        for attempt in 1...3 {
            field.tap()
            if app.keyboards.element.waitForExistence(timeout: 5) {
                field.typeText(text)
                return
            }
            if attempt == 3 {
                capture(app, named: "00-sin-teclado")
                throw XCTSkip("El teclado no apareció tras 3 toques en \(field.identifier).")
            }
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

    /// Attaches the app's element tree.
    ///
    /// Guessing which element kind SwiftUI made of a row cost two runs. The
    /// tree is the only thing that answers it.
    private func attachHierarchy(_ app: XCUIApplication) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = "jerarquia"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
