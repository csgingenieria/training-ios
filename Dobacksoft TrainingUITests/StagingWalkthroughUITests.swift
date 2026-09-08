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
/// a machine with no backend access — and that is the trap. `xcodebuild`
/// reports exit 0 and «TEST SUCCEEDED» for a run in which none of these tests
/// executed. A verification pass must therefore add `STAGING_REQUIRED`:
///
/// ```
/// TEST_RUNNER_STAGING_EMAIL=… TEST_RUNNER_STAGING_PASSWORD=… \
///   TEST_RUNNER_STAGING_REQUIRED=1 xcodebuild test …
/// ```
///
/// With it, missing credentials fail instead of skipping, so a green run cannot
/// be mistaken for coverage that never ran. Without it, the skip stays correct
/// for anyone who has no staging access at all.
///
/// ## Two accounts means two runs, and each must say which it is
///
/// There is a candidate account and an instructor account. The walkthrough
/// skips the screens a role does not have, which is right — but it cannot tell
/// «this role does not have it» from «this screen is broken». With the
/// candidate account, if «Mi posición» stopped opening, it would skip exactly
/// as it does for an instructor, and the run would still report success.
///
/// So a verification pass declares the role, and then the screens that role
/// owns can no longer be skipped:
///
/// ```
/// # Aspirante: «Mi posición» y «Mi progreso» son obligatorias.
/// TEST_RUNNER_STAGING_EMAIL=… TEST_RUNNER_STAGING_PASSWORD=… \
///   TEST_RUNNER_STAGING_REQUIRED=1 TEST_RUNNER_STAGING_ROLE=student \
///   xcodebuild test … -only-testing:"Dobacksoft TrainingUITests/StagingWalkthroughUITests"
///
/// # Instructor: «Resultados» es obligatoria.
/// TEST_RUNNER_STAGING_EMAIL=… TEST_RUNNER_STAGING_PASSWORD=… \
///   TEST_RUNNER_STAGING_REQUIRED=1 TEST_RUNNER_STAGING_ROLE=manager \
///   xcodebuild test … -only-testing:"Dobacksoft TrainingUITests/StagingWalkthroughUITests"
/// ```
///
/// An unrecognised `STAGING_ROLE` fails rather than being ignored: a typo
/// («aspirante» for «student») would leave the run believing it verifies more
/// than it does.
@MainActor
final class StagingWalkthroughUITests: XCTestCase {
    private var credentials: (email: String, password: String)!

    /// Qué rol se está usando en esta corrida, si se declara.
    ///
    /// Existe porque hay DOS cuentas de staging, una de aspirante y otra de
    /// instructor, y sin declararlo dos corridas no compran cobertura de nada.
    /// El recorrido se salta las pantallas que el rol no tiene —correcto—, pero
    /// **no distingue «este rol no la tiene» de «esta pantalla está rota»**: con
    /// la cuenta de aspirante, si «Mi posición» dejara de abrir, se saltaría
    /// igual y la corrida diría «TEST SUCCEEDED». Es el mismo agujero que
    /// `STAGING_REQUIRED` cierra un nivel más abajo.
    ///
    /// Declarado el rol, la pantalla que ESE rol debe tener ya no se puede
    /// saltar: falla.
    private enum StagingRole: String {
        case student
        case manager

        /// Si este rol tiene «Mi posición» y «Mi progreso».
        var hasOwnStanding: Bool { self == .student }

        /// Si este rol tiene «Resultados» y el panel.
        var hasResultados: Bool { self == .manager }
    }

    private var declaredRole: StagingRole?

    /// Se salta, o falla si el rol declarado dice que esa pantalla es suya.
    ///
    /// `expected` es la pregunta «¿este rol debería tener esto?». Con el rol sin
    /// declarar no se sabe, y el salto sigue siendo lo honesto.
    private func skipUnlessTheRoleShouldHaveIt(
        _ screen: String,
        expected: (StagingRole) -> Bool,
        detail: String
    ) throws {
        if let role = declaredRole, expected(role) {
            XCTFail(
                "«\(screen)» no apareció, y el rol declarado (\(role.rawValue)) SÍ la tiene. "
                + "Esto es un fallo del recorrido, no una pantalla que este rol no use. "
                + detail
            )
            return
        }
        // Dos saltos distintos, y decirlos igual desinforma: la primera
        // corrida con rol declarado escribió «declaralo con
        // TEST_RUNNER_STAGING_ROLE» en un log donde el rol SÍ estaba puesto.
        // Quien lo leyera concluiría que la corrida no valía.
        if let role = declaredRole {
            throw XCTSkip(
                "«\(screen)» no aparece, y es correcto: el rol declarado "
                + "(\(role.rawValue)) no la tiene. \(detail) "
                + "Este salto es esperado y no oculta nada."
            )
        }
        throw XCTSkip(
            "«\(screen)» no apareció. \(detail) "
            + "SIN STAGING_ROLE no se puede saber si este rol debería tenerla, así que "
            + "esta corrida NO prueba nada sobre esa pantalla. Declaralo con "
            + "TEST_RUNNER_STAGING_ROLE=student|manager."
        )
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        let env = ProcessInfo.processInfo.environment
        let email = env["STAGING_EMAIL"] ?? ""
        let password = env["STAGING_PASSWORD"] ?? ""

        guard !email.isEmpty, !password.isEmpty else {
            // Sin credenciales esta suite no prueba NADA, y hasta ahora lo
            // hacía en silencio: `xcodebuild` da exit 0 y «TEST SUCCEEDED»
            // con los tres tests saltados, así que quien verificara así
            // —una sesión nueva, un CI, el dueño del proyecto— se llevaba un
            // verde y creía que había cobertura. Es el mismo patrón que esta
            // suite existe para cazar, y más silencioso que los demás porque
            // no deja ni un rojo que mirar.
            //
            // El salto sigue siendo correcto para quien no tiene acceso a
            // staging. Lo que cambia es que ya no se puede confundir con una
            // verificación: una corrida seria pasa STAGING_REQUIRED=1 y
            // entonces la ausencia de credenciales es un FALLO, no un salto.
            if (env["STAGING_REQUIRED"] ?? "").isEmpty == false {
                XCTFail(
                    "STAGING_REQUIRED está puesto y no hay credenciales: "
                    + "esta corrida no habría probado nada del recorrido. "
                    + "Pasá TEST_RUNNER_STAGING_EMAIL y TEST_RUNNER_STAGING_PASSWORD."
                )
                return
            }
            throw XCTSkip(
                "SIN CREDENCIALES: este recorrido NO se ha ejecutado y esta corrida "
                + "no prueba nada sobre él, aunque xcodebuild diga «TEST SUCCEEDED». "
                + "Para una verificación de verdad: "
                + "TEST_RUNNER_STAGING_EMAIL=… TEST_RUNNER_STAGING_PASSWORD=… "
                + "TEST_RUNNER_STAGING_REQUIRED=1 xcodebuild test …"
            )
        }
        credentials = (email, password)

        // El rol es opcional, pero un valor que no reconocemos NO se ignora en
        // silencio: una errata («aspirante» en vez de «student») dejaría la
        // corrida creyendo que verifica más de lo que verifica.
        let rawRole = (env["STAGING_ROLE"] ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        if !rawRole.isEmpty {
            guard let role = StagingRole(rawValue: rawRole) else {
                XCTFail("STAGING_ROLE=«\(rawRole)» no se reconoce. Valores: student, manager.")
                return
            }
            declaredRole = role
        }
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
        // «Mi posición» es una pestaña en iPhone y una fila del sidebar en
        // iPad, y la del sidebar no se puede accionar desde XCUITest. Pero
        // también se llega desde el detalle de la convocatoria, que es un
        // camino que un aspirante usa y que existe en los dos layouts.
        if destinations(in: app).contains("Mi posición"), navigate(to: "Mi posición", in: app) {
            // Llegado por la pestaña.
        } else {
            let convocatoria = try openConvocatoria(in: app)
            convocatoria.tap()

            // Acotado al panel de detalle: en iPad hay DOS elementos con esta
            // etiqueta —la fila de acción y la del sidebar— y la consulta sin
            // acotar es ambigua. El sidebar vive en un CollectionView; la fila
            // de acción, en un ScrollView.
            let miPosicion = app.scrollViews.buttons["Mi posición"].firstMatch
            guard miPosicion.waitForExistence(timeout: 10) else {
                try skipUnlessTheRoleShouldHaveIt(
                    "Mi posición",
                    expected: \.hasOwnStanding,
                    detail: "Los intentos se alcanzan por otro sitio en los roles que no la tienen."
                )
                return
            }
            miPosicion.tap()
            XCTAssertTrue(
                app.navigationBars["Mi posición"].waitForExistence(timeout: 15),
                "«Mi posición» no abrió desde el detalle de la convocatoria."
            )
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
        // La llegada se prueba por algo que es SOLO del detalle del intento.
        //
        // Antes era «apareció algún botón en la barra», y «Mi posición» tiene
        // su propia barra con el menú de orden: la aserción se cumplía en la
        // pantalla de origen tanto como en la de destino, y por eso este test
        // pasaba dos corridas y fallaba la tercera sin que cambiara nada.
        XCTAssertTrue(
            element("attempt.openMap", in: app).waitForExistence(timeout: 20),
            "Tapping «\(attempt.label)» did not push the attempt detail."
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
    /// «Mi progreso», la ficha del recorrido y el mapa: las pantallas que
    /// consumen los seis endpoints nuevos y que **nada había ejercitado contra
    /// datos reales**.
    ///
    /// Es el código más joven de la app y el que más puede romperse en
    /// silencio: cada una decodifica una respuesta que llegó hace días, y un
    /// fallo de decodificación aquí no es un bug de andar por casa — es un
    /// aspirante que abre su progreso y ve un error donde debería estar su
    /// nota.
    ///
    /// La auditoría no podía cubrir esto: leyó código. Lo que el backend
    /// compone con datos de verdad solo se ve corriéndolo.
    func testMiProgreso() throws {
        let app = launchClean()
        try signIn(app)
        dismissSystemSavePasswordSheet()

        guard app.tabBars.firstMatch.exists else {
            throw XCTSkip(
                "Layout de sidebar: XCUITest no acciona la selección de un List de SwiftUI. "
                + "Mismo límite que el recorrido general."
            )
        }

        let progreso = app.tabBars.buttons["Mi progreso"]
        guard progreso.waitForExistence(timeout: 15) else {
            try skipUnlessTheRoleShouldHaveIt(
                "Mi progreso",
                expected: \.hasOwnStanding,
                detail: "Solo el aspirante tiene progreso propio."
            )
            return
        }

        XCTAssertTrue(select(progreso, attempts: 3), "«Mi progreso» no llegó a seleccionarse.")

        // La pantalla tiene que resolverse: o su título, o su vacío explicado.
        // Lo que NO puede es quedarse en el error de decodificación.
        XCTAssertTrue(
            app.navigationBars["Mi progreso"].waitForExistence(timeout: 20),
            "«Mi progreso» no llegó a renderizar su barra."
        )
        capture(app, named: "20-mi-progreso")
        assertNoDecodingFailureVisible(app, screen: "Mi progreso")
        assertNoVerdictVisible(app, screen: "Mi progreso")

        // Un error de carga es un fallo del recorrido, no un estado válido:
        // esta pantalla es nueva y su endpoint también, y «Reintentar» visible
        // significa que la respuesta real no se pudo consumir.
        XCTAssertFalse(
            element("progreso.retry", in: app).exists,
            "«Mi progreso» abrió en error contra staging: su endpoint no se pudo consumir."
        )

        // La ficha del recorrido, si hay recorridos calificados. Sin ellos la
        // pantalla enseña su vacío, que es legítimo y no se fuerza.
        let fila = element("progreso.row", in: app)
        guard fila.waitForExistence(timeout: 10) else {
            throw XCTSkip(
                "Esta cuenta no tiene recorridos calificados, así que la ficha del "
                + "recorrido y el mapa NO quedan cubiertos por esta corrida."
            )
        }

        fila.tap()
        // Se espera la pantalla de destino por su identidad, no «algún botón
        // en la barra»: eso último se cumple también en la de origen, y este
        // test pasaba corriendo solo y fallaba en la tanda completa. Un test
        // que solo falla acompañado es peor que uno que falla siempre — sale
        // verde en la máquina de quien lo escribe.
        XCTAssertTrue(
            element("recorrido.pantalla", in: app).waitForExistence(timeout: 20),
            "La fila de progreso no abrió la ficha del recorrido."
        )
        capture(app, named: "21-ficha-recorrido")
        assertNoDecodingFailureVisible(app, screen: "Ficha del recorrido")
        assertNoVerdictVisible(app, screen: "Ficha del recorrido")
        XCTAssertFalse(
            element("recorrido.retry", in: app).exists,
            "La ficha del recorrido abrió en error contra staging."
        )

        // Y el mapa. Va DOS saltos más allá, no uno: el enlace al mapa vive en
        // el detalle del intento, no en la ficha del recorrido. La primera
        // versión de este test lo buscaba aquí y se saltó diciendo que no
        // cubría el GPS — el salto hizo su trabajo, la navegación era mía y
        // estaba mal.
        app.swipeUp()
        let vuelta = element("recorrido.vuelta", in: app)
        guard vuelta.waitForExistence(timeout: 8) else {
            throw XCTSkip(
                "Esta ficha no tiene vueltas conducidas, así que el detalle del "
                + "intento y el payload de GPS NO quedan cubiertos por esta corrida."
            )
        }
        vuelta.tap()
        // Por lo mismo: el detalle del intento se reconoce por su enlace al
        // mapa, que es suyo y de ninguna otra pantalla.
        XCTAssertTrue(
            element("attempt.openMap", in: app).waitForExistence(timeout: 20),
            "La vuelta no abrió el detalle del intento desde la ficha del recorrido."
        )
        assertNoDecodingFailureVisible(app, screen: "Intento desde la ficha")

        // El payload más complicado de los seis: segmentos, traza ajustada y
        // eventos con coordenadas.
        element("attempt.openMap", in: app).tap()
        capture(app, named: "22-mapa-del-intento")
        assertNoDecodingFailureVisible(app, screen: "Mapa del intento")
        XCTAssertFalse(
            element("mapa.retry", in: app).exists,
            "El mapa abrió en error contra staging: el payload de GPS no se pudo consumir."
        )
    }

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

        let row = try openConvocatoria(in: app)
        row.tap()

        let resultados = app.buttons["Resultados"]
        guard resultados.waitForExistence(timeout: 10) else {
            try skipUnlessTheRoleShouldHaveIt(
                "Resultados",
                expected: \.hasResultados,
                detail: "Es una pantalla solo de instructor."
            )
            return
        }
        resultados.tap()

        XCTAssertTrue(
            app.staticTexts["Aspirante"].waitForExistence(timeout: 20),
            "«Resultados» never rendered its table header."
        )
        capture(app, named: "20-resultados")

        assertNoDecodingFailureVisible(app, screen: "Resultados")
        assertNoVerdictVisible(app, screen: "Resultados")

        // Y desde una celda, el detalle del intento.
        //
        // Es el ÚNICO camino que el instructor tiene a esa pantalla —no tiene
        // «Mi posición»— y era el que nadie había recorrido nunca contra datos
        // reales. Entra además por la puerta que pasa `finality: .unknown` y
        // sin fecha, que es una combinación que solo se da aquí.
        let cualquierCelda = element("resultados.celda", in: app)
        guard cualquierCelda.waitForExistence(timeout: 10) else {
            throw XCTSkip(
                "Esta convocatoria no tiene ninguna celda con nota, así que el "
                + "detalle del intento por el camino del instructor NO queda cubierto."
            )
        }

        // El toque va por coordenada, no por `tap()` ni por `isHittable`.
        //
        // La matriz es un `LazyVStack` dentro de un `ScrollView` de dos ejes:
        // las celdas fuera del viewport **no tienen marco**, y preguntar por su
        // alcanzabilidad no devuelve `false` — revienta con «Activation point
        // invalid and no suggested hit points based on element frame». Así que
        // enumerarlas para buscar una tocable es justamente lo que no se puede
        // hacer.
        //
        // Es el mismo límite de XCUITest que este archivo ya documenta para el
        // sidebar del iPad, y se trata igual: se intenta por coordenada y, si
        // no se puede, se dice en voz alta qué queda sin cubrir en lugar de
        // dejar un rojo que acusa a la app de algo que no ha hecho.
        cualquierCelda.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Dos preguntas distintas, y confundirlas acusa en falso.
        //
        // «¿Navegó?» se contesta con el título, que existe en TODOS los estados
        // de esa pantalla —cargando, cargado y error—. «¿Cargó?» se contesta
        // con el enlace al mapa, que solo existe cargado. Con una sola
        // aserción sobre el enlace, una pantalla que abrió y falló al cargar se
        // reporta como una celda que no navega: un defecto que no existe, en
        // lugar del que sí.
        guard app.navigationBars["Intento"].waitForExistence(timeout: 20) else {
            capture(app, named: "21-celda-no-navega")

            // Caso de control antes de culpar a la herramienta.
            //
            // La columna del nombre es otro `NavigationLink` en la MISMA
            // tabla. Si ESA navega, el contenedor no se come nada y lo de la
            // celda es direccionamiento. Si tampoco navega, hay algo real en
            // la matriz y no se puede seguir llamándolo límite de XCUITest.
            let aspirante = element("resultados.aspirante", in: app)
            if aspirante.waitForExistence(timeout: 5) {
                aspirante.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                let abrio = app.navigationBars["Aspirante"].waitForExistence(timeout: 15)
                XCTAssertTrue(
                    abrio,
                    "Ningún enlace de la matriz navega —ni la celda ni el nombre—, "
                    + "así que esto NO es un límite de XCUITest: la tabla del "
                    + "instructor no abre nada."
                )
                if abrio {
                    capture(app, named: "22-perfil-desde-la-matriz")
                    assertNoDecodingFailureVisible(app, screen: "Aspirante desde la matriz")
                }
            }

            throw XCTSkip(
                "El toque sintético sobre una celda de la matriz no abrió el detalle. "
                + "Las celdas viven en un LazyVStack dentro de un ScrollView de dos "
                + "ejes y XCUITest no las direcciona de forma fiable — el mismo límite "
                + "que el sidebar del iPad. VERIFICADO: la matriz decodifica una "
                + "respuesta real, pinta su cabecera y no deja ver ningún veredicto. "
                + "SIN cubrir: el detalle del intento por el camino del instructor."
            )
        }
        capture(app, named: "21-intento-desde-la-matriz")
        assertNoDecodingFailureVisible(app, screen: "Intento desde la matriz")
        assertNoVerdictVisible(app, screen: "Intento desde la matriz")

        XCTAssertTrue(
            element("attempt.openMap", in: app).waitForExistence(timeout: 20),
            "El detalle abrió por el camino del instructor y no llegó a cargar."
        )
    }

    /// The convocatoria row, by whichever route this layout offers.
    ///
    /// iPhone reaches it from the Convocatorias tab. iPad regular width lands a
    /// manager on Panel and a candidate on Convocatorias, and the sidebar
    /// cannot be driven — but the dashboard lists the active convocatorias with
    /// the same identifier, so the row is reachable without it. Both are paths
    /// a person actually takes; neither is a workaround.
    private func openConvocatoria(in app: XCUIApplication) throws -> XCUIElement {
        // La ruta canónica de cada layout primero.
        //
        // Con tab bar, la lista de Convocatorias. Probar antes la fila que
        // tenga a mano encontraba en iPhone la del PANEL —que lleva el mismo
        // identificador a propósito— fuera de la parte visible, y XCUITest
        // fallaba con «not hittable» sobre un botón que existía. Existir no es
        // poder tocarse, otra vez.
        if app.tabBars.firstMatch.exists {
            if navigate(to: "Convocatorias", in: app),
               let row = hittableRow("convocatorias.row", in: app) {
                return row
            }
        } else {
            // Sidebar: el instructor aterriza en Panel y el aspirante en
            // Convocatorias, y la selección del sidebar no es automatizable.
            // Cada uno tiene su propia fila, con su propio identificador.
            // El del panel primero: el instructor aterriza ahí. Probar antes
            // el de la lista gastaba los tres intentos —con swipeUp entre
            // ellos— y dejaba el panel scrolleado antes de mirar el correcto.
            for identifier in ["panel.convocatoria", "convocatorias.row"] {
                if let row = hittableRow(identifier, in: app) { return row }
            }
        }

        capture(app, named: "19-sin-convocatoria")
        attachHierarchy(app)
        throw XCTSkip("No hay ninguna «convocatorias.row» que se pueda tocar. Ver la jerarquía adjunta.")
    }

    /// La primera fila de convocatoria que de verdad se puede tocar, subiendo
    /// el scroll si hace falta.
    private func hittableRow(_ identifier: String, in app: XCUIApplication) -> XCUIElement? {
        for attempt in 0..<3 {
            let row = element(identifier, in: app)
            if row.waitForExistence(timeout: attempt == 0 ? 8 : 2), row.isHittable {
                return row
            }
            app.swipeUp()
        }
        return nil
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

        for attempt in 1...4 {
            field.tap()
            guard app.keyboards.element.waitForExistence(timeout: 5) else { continue }

            // `field.typeText`, NO `app.typeText`.
            //
            // Cambié a `app.typeText` para esquivar su aserto de foco y fue al
            // revés: ese aserto es la protección. `app.typeText` escribe donde
            // esté el cursor, así que en iPad la contraseña se fue dentro del
            // campo de email —el foco no había saltado todavía— y el login
            // falló con «No session» en los tres tests. El mismo error que
            // cometí a mano al principio del día.
            //
            // La intermitencia se resuelve dándole tiempo al foco y
            // reintentando, no saltándose la comprobación.
            guard fieldHasFocus(field) else { continue }
            field.typeText(text)

            if fieldAcceptedText(field) { return }
            if attempt == 4 {
                capture(app, named: "00-sin-foco")
                attachHierarchy(app)
                throw XCTSkip("El campo \(field.identifier) no aceptó texto tras 4 intentos.")
            }
        }
    }

    /// Espera a que el campo tenga de verdad el foco del teclado.
    ///
    /// Que el teclado esté en pantalla no significa que ESTE campo lo tenga:
    /// entre tocar y recibir el foco hay una ventana, y escribir dentro de esa
    /// ventana manda el texto al campo anterior.
    private func fieldHasFocus(_ field: XCUIElement, timeout: TimeInterval = 4) -> Bool {
        let focused = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hasKeyboardFocus == true"),
            object: field
        )
        return XCTWaiter.wait(for: [focused], timeout: timeout) == .completed
    }

    /// `true` cuando el campo tiene algo escrito.
    ///
    /// Un campo seguro no devuelve su contenido —enseña puntos— así que ahí lo
    /// comprobable es que dejó de mostrar su marcador de posición.
    private func fieldAcceptedText(_ field: XCUIElement) -> Bool {
        guard let value = field.value as? String else { return false }
        if let placeholder = field.placeholderValue, value == placeholder { return false }
        return !value.isEmpty
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
