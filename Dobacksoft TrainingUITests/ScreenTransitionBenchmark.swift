import XCTest

/// How long a screen switch actually takes, **with error bars**.
///
/// Written because the number that closed audit item #26 could not support the
/// claim made on it. «139 s sin animaciones · 136 s con las locales · 304 s con
/// el fundido» were three single runs of the whole walkthrough, and on
/// 2026-09-10 the same two tests, on identical code, ran:
///
///     testSignedInWalkthrough   65 s → 83 s → 135 s
///     testWidgetSnapshot        39 s → 50 s →  75 s
///
/// Monotonically increasing across the session, both tests, no code change.
/// A single wall-clock run of a whole walkthrough measures the machine's mood
/// at least as much as it measures the app.
///
/// `measure(metrics:)` is the instrument that answers this: N iterations inside
/// ONE launch, reported as average and standard deviation, so drift between
/// runs cannot masquerade as an effect.
///
/// **Not part of the walkthrough.** It needs staging credentials and it is a
/// benchmark, not an assertion, so it only runs when asked:
///
///     TEST_RUNNER_BENCHMARK=1 xcodebuild test \
///       -only-testing:"Dobacksoft TrainingUITests/ScreenTransitionBenchmark"
final class ScreenTransitionBenchmark: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["BENCHMARK"] == "1",
            "Benchmark: se corre a mano con BENCHMARK=1, no en el recorrido."
        )
    }

    /// Switching between two tabs, measured five times in one launch.
    ///
    /// The tab switch is the cheapest thing that crosses the animated boundary:
    /// «Mi posición» and «Convocatorias» are two of the three screens the audit
    /// proposed fading, so if the fade costs anything measurable, it is here.
    func testTabSwitchDuration() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset-session", "-uitest-redact-secrets"]
        app.launch()

        try signIn(app)

        let convocatorias = app.tabBars.buttons["Convocatorias"]
        let posicion = app.tabBars.buttons["Mi posición"]
        guard convocatorias.waitForExistence(timeout: 30), posicion.exists else {
            throw XCTSkip("Esta cuenta no tiene las dos pestañas que mide el banco de pruebas.")
        }

        // Una vez cada una antes de medir: la PRIMERA visita carga de red, y
        // meterla en la medición mediría la red, no la transición.
        convocatorias.tap()
        _ = app.navigationBars["Convocatorias"].waitForExistence(timeout: 30)
        posicion.tap()
        _ = app.navigationBars["Mi posición"].waitForExistence(timeout: 30)

        measure(metrics: [XCTClockMetric()]) {
            convocatorias.tap()
            _ = app.navigationBars["Convocatorias"].waitForExistence(timeout: 10)
            posicion.tap()
            _ = app.navigationBars["Mi posición"].waitForExistence(timeout: 10)
        }
    }

    private func signIn(_ app: XCUIApplication) throws {
        let env = ProcessInfo.processInfo.environment
        let email = try XCTUnwrap(env["STAGING_EMAIL"], "Falta STAGING_EMAIL")
        let password = try XCTUnwrap(env["STAGING_PASSWORD"], "Falta STAGING_PASSWORD")

        let campoEmail = app.textFields["login.email"]
        XCTAssertTrue(campoEmail.waitForExistence(timeout: 30), "no salió el formulario de acceso")
        campoEmail.tap()
        campoEmail.typeText(email)

        let campoPassword = app.secureTextFields["login.password"]
        campoPassword.tap()
        campoPassword.typeText(password)

        app.buttons["login.submit"].tap()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 60)
                || app.staticTexts["Perfil"].waitForExistence(timeout: 5),
            "no se abrió la sesión contra staging"
        )
    }
}
