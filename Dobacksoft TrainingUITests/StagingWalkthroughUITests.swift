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

        // Ancho compacto da un TabView; ancho regular, un NavigationSplitView.
        // Los dos se recorren, y sus destinos se leen igual (`destinations`).
        //
        // Este test se SALTABA el layout de sidebar entero, citando que
        // «XCUITest no acciona la selección de un List de SwiftUI» con seis
        // aproximaciones probadas y afirmando que la app estaba bien porque
        // «una persona lo toca y se mueve».
        //
        // No estaba bien. Las filas eran `Label` con `.tag()`, y una fila de
        // List en iOS **no es seleccionable al toque** fuera del modo edición:
        // no le faltaba nada a la herramienta, le faltaba el
        // `NavigationLink(value:)` que Apple documenta para ese sidebar. Medido
        // así: la fila mide 288×52 pt, está donde dice, se toca en su centro y
        // el panel no se movía. En iPad ese sidebar es la vía principal de
        // todo, y no funcionaba para nadie.
        //
        // El salto se retira porque ya no hay nada que saltar. `testIPadSidebar`
        // guarda el control que separa las dos causas, para que la próxima nota
        // heredada tenga que demostrarse.

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
        // iPad. Se llega también desde el detalle de la convocatoria, que es un
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
        guard element("standing.attempt", in: app).waitForExistence(timeout: 5) else {
            throw XCTSkip("This account has no recorded attempt to open.")
        }

        // Por `hittableRow`, como las filas del perfil.
        //
        // Esta se buscaba con `element` a secas después de dos `swipeUp` a
        // ciegas: sin comprobar que quedara libre de la barra flotante y sin
        // esperar a que el `List` dejara de moverse. En iPhone caía debajo de
        // la barra y los cuatro reintentos tocaban cuatro veces el mismo sitio
        // tragado. «Existe» nunca fue «se puede tocar», y aquí lo era menos.
        guard let attempt = hittableRow("standing.attempt", in: app) else {
            return XCTFail("«standing.attempt» existe pero no se puede tocar: algo lo tapa y no se destapa.")
        }

        // La llegada se prueba por algo que es SOLO del detalle del intento.
        //
        // Antes era «apareció algún botón en la barra», y «Mi posición» tiene
        // su propia barra con el menú de orden: la aserción se cumplía en la
        // pantalla de origen tanto como en la de destino, y por eso este test
        // pasaba dos corridas y fallaba la tercera sin que cambiara nada.
        //
        // Y el toque se reintenta, como el del perfil: en iPad este paso
        // fallaba con la fila visible y tocable. Mismo ocultador, misma
        // inercia, mismo diagnóstico falso —«la app no empuja el detalle»—
        // sobre un toque que nunca llegó.
        let llegó = tapUntilArriving(
            attempt,
            at: element("attempt.openMap", in: app),
            attempts: 3,
            timeout: 15
        )
        XCTAssertTrue(
            llegó,
            // **Sin la etiqueta de la fila.** Llevaba el nombre del recorrido,
            // la fecha y la nota de una persona a un log que puede acabar en un
            // CI o pegado en un chat. El identificador dice lo mismo para
            // depurar y no dice nada de nadie.
            "«standing.attempt» no abrió el detalle del intento."
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
    /// «Mi PIN de tablet»: que la pantalla resuelva contra el endpoint real.
    ///
    /// ⚠ **Este test NO captura la pantalla y NO lee el PIN.** Es la única
    /// pantalla de la app cuyo contenido es una credencial: con el PIN y el
    /// número de inscripción se puede conducir en nombre de otra persona. Una
    /// captura acabaría en el bundle de resultados, que se comparte; el valor
    /// en un mensaje de fallo acabaría en un log. Así que se comprueba que la
    /// pantalla **resuelve**, nunca qué dice.
    ///
    /// ⚠ **Cada corrida deja una entrada en el registro de auditoría** de la
    /// cuenta de staging: el backend audita toda consulta del PIN, también las
    /// que fallan. Es lo correcto —es una credencial— y por eso este test es
    /// uno y no un bucle.
    func testMiPin() throws {
        let app = launchClean()
        try signIn(app)
        dismissSystemSavePasswordSheet()

        guard destinations(in: app).contains("Perfil") else {
            return XCTFail("Sin «Perfil» no hay camino al PIN: la sesión no llegó a abrirse.")
        }
        XCTAssertTrue(navigate(to: "Perfil", in: app), "«Perfil» no llegó a abrirse.")

        // `hittableRow`, no `waitForExistence` + `tap()`.
        //
        // La fila vive en un `Form`, bajo el pliegue: existe en la jerarquía
        // desde el primer momento y un toque sobre ella no hace nada hasta que
        // se scrollea. Este test pasaba corriéndose solo y fallaba en la tanda
        // —el `Form` queda scrolleado de otra manera— y el síntoma era «la fila
        // del perfil no abrió Mi PIN», que suena a defecto de la app.
        //
        // «Existir no es poder tocarse» ya estaba aprendido en este archivo dos
        // veces. Tercera.
        guard let fila = hittableRow("profile.pin", in: app) else {
            try skipUnlessTheRoleShouldHaveIt(
                "Mi PIN de tablet",
                expected: \.hasOwnStanding,
                detail: "El PIN es del aspirante: el endpoint es STUDENT-only."
            )
            return
        }

        fila.tap()

        XCTAssertTrue(
            app.navigationBars["Mi PIN"].waitForExistence(timeout: 20),
            "La fila del perfil no abrió «Mi PIN»."
        )
        assertNoDecodingFailureVisible(app, screen: "Mi PIN")

        // Que el endpoint se haya consumido: si está «Reintentar», no se pudo.
        XCTAssertFalse(
            element("pin.retry", in: app).exists,
            "«Mi PIN» abrió en error contra staging: su endpoint no se pudo consumir."
        )

        // Y que la advertencia esté. Es lo único que se afirma del contenido:
        // una pantalla que entrega una credencial sin decir lo que vale sería
        // peor que no entregarla.
        //
        // El fragmento va escrito a mano porque este target corre FUERA de
        // proceso y no ve los tipos de la app: no hay `PinCopy` al que
        // preguntar. Duplicar copia deriva, así que
        // `PinCopyTests.theWarningKeepsThePhraseTheUITestLooksFor` fija que la
        // frase real lo siga conteniendo — si alguien la reescribe, salta ahí y
        // no aquí, con el recorrido en verde.
        let advertencia = app.staticTexts
            .containing(NSPredicate(format: "label CONTAINS %@", "conducir en su nombre"))
            .firstMatch
        XCTAssertTrue(
            advertencia.waitForExistence(timeout: 5),
            "«Mi PIN» no advierte de lo que valen esos datos."
        )

        // El caso de control de la redacción.
        //
        // Sin él, `-uitest-redact-secrets` y `.privacySensitive()` serían dos
        // marcadores que se creen mutuamente sin tapar nada — y toda la
        // garantía de que el PIN no puede filtrarse desde un test descansa en
        // que de verdad no se dibuje.
        //
        // Se comprueba por AUSENCIA de patrón, no leyendo el valor: si la
        // etiqueta «Su PIN es …» sobrevive con dígitos dentro, la cifra sigue
        // expuesta a VoiceOver y a XCUITest aunque la pantalla se vea tapada,
        // y eso sería un hallazgo, no un detalle.
        let expuesto = app.staticTexts.allElementsBoundByIndex
            .prefix(60)
            .compactMap { $0.exists ? $0.label : nil }
            .filter { etiqueta in
                etiqueta.hasPrefix("Su PIN es")
                    && etiqueta.rangeOfCharacter(from: .decimalDigits) != nil
            }
        XCTAssertTrue(
            expuesto.isEmpty,
            "La redacción no tapa el PIN: sigue accesible como etiqueta. "
            + "\(expuesto.count) elemento(s) lo exponen. "
            + "El valor NO se escribe aquí a propósito."
        )

        // ⚠ Lo que este control NO puede distinguir, dicho en voz alta: si esta
        // cuenta de staging no tuviera PIN, la pantalla enseñaría su mensaje de
        // «no se puede mostrar», no habría etiqueta que tapar, y la aserción de
        // arriba pasaría sin haber probado la redacción.
        //
        // Resolverlo pediría una corrida SIN la bandera para ver la etiqueta
        // aparecer — y eso es exactamente lo que no se va a hacer, porque
        // dibujaría la credencial en una corrida que puede fallar y guardar la
        // captura. Se prefiere un control con un límite escrito a una garantía
        // comprada renderizando un PIN ajeno.
    }

    /// El cambio de contraseña, **sin cambiar ninguna**.
    ///
    /// Automatizar el cambio de verdad mutaría la contraseña de staging y
    /// dejaría obsoletas las credenciales del Keychain, rompiendo todas las
    /// corridas futuras. Eso pide una cuenta desechable y no se hace aquí.
    ///
    /// Pero descartar la pantalla entera por eso era ir demasiado lejos: hay
    /// una vía que la ejercita de punta a punta **sin efecto alguno** — enviar
    /// una contraseña actual EQUIVOCADA. El backend la rechaza, nada cambia, y
    /// se comprueba lo que de verdad podía estar roto: que la pantalla llegue,
    /// que el formulario se valide, que la petición salga y que el rechazo se
    /// cuente en castellano en vez de dejar a alguien mirando un botón muerto.
    ///
    /// La contraseña nueva que se teclea nunca llega a aplicarse, porque la
    /// actual no valida. Es deliberado: el orden de las comprobaciones del
    /// backend es lo que hace segura esta prueba.
    func testChangePasswordRejectsAWrongCurrentOne() throws {
        let app = launchClean()
        try signIn(app)
        dismissSystemSavePasswordSheet()

        guard destinations(in: app).contains("Perfil") else {
            return XCTFail("Sin «Perfil» no hay camino: la sesión no llegó a abrirse.")
        }
        XCTAssertTrue(navigate(to: "Perfil", in: app), "«Perfil» no llegó a abrirse.")

        // La llegada se COMPRUEBA, no se cree.
        //
        // `navigate` devuelve un booleano y el test lo trataba como la llegada.
        // Devolvió `true` con la app en «Convocatorias», y a partir de ahí todo
        // lo demás —una fila «direccionable», un toque, una espera de veinte
        // segundos— midió la pantalla equivocada y acusó a la app de no
        // empujar una pantalla que nadie le había pedido.
        XCTAssertTrue(
            app.navigationBars["Perfil"].waitForExistence(timeout: 10),
            "«navigate» dijo que sí y la pantalla abierta es otra."
        )

        guard let fila = hittableRow("profile.password", in: app) else {
            return XCTFail("«Cambiar la contraseña» no está en el perfil.")
        }
        // Qué se está tocando, exactamente.
        //
        // «La fila existe y es tocable» no dice cuál de los elementos con ese
        // identificador se resolvió —una fila de `Form` produce una celda Y un
        // botón— ni dónde cae el toque. Sin esto, un toque en el sitio
        // equivocado se lee como una pantalla que no se empuja.
        let marco = fila.frame
        let queSeToca = "tipo=\(fila.elementType.rawValue)"
            + " botones=\(app.buttons.matching(identifier: "profile.password").count)"
            + " celdas=\(app.cells.matching(identifier: "profile.password").count)"
            + " marco=\(Int(marco.minX)),\(Int(marco.minY)) \(Int(marco.width))x\(Int(marco.height))"
            + " pantalla=\(Int(app.frame.width))x\(Int(app.frame.height))"

        // El toque se REPITE hasta que la pantalla cambia.
        //
        // Un toque que algo se traga no deja rastro: la app queda exactamente
        // como estaba, así que repetirlo es seguro y empujar dos veces no puede
        // pasar —en cuanto la barra de destino aparece, se para.
        //
        // Hace falta porque «la fila existe, es tocable, está quieta y libre de
        // la barra» sigue sin garantizar que el toque llegue: XCUITest calcula
        // la coordenada de un árbol que ya cambió. Sin esto el test pasaba unas
        // veces y otras no, y las que no acusaban a la app de no empujar.
        tapUntilPushed(fila, destination: "Contraseña", in: app)

        // «¿Navegó?» con el título, que existe en todos los estados de la
        // pantalla; «¿el campo es direccionable?» aparte. Confundirlas acusa en
        // falso, que es la lección que ya costó dos investigaciones hoy.
        // Se MUESTREA en vez de esperar.
        //
        // `waitForExistence` dice «no llegó» y calla la diferencia que importa:
        // una pantalla que nunca se empujó y una que se empujó y volvió sola
        // dan el mismo fallo y piden arreglos opuestos. Esto graba la secuencia
        // y la pone en el mensaje.
        let visita = sampleNavigationBar("Contraseña", in: app, seconds: 20)
        XCTAssertTrue(
            visita.everAppeared,
            """
            La fila del perfil no abrió la pantalla de cambio de contraseña.
            Se tocó: \(queSeToca)
            Barras vistas durante la espera: \(visita.barsSeen.joined(separator: " → "))
            """
        )
        XCTAssertTrue(
            visita.stillThere,
            """
            «Contraseña» se abrió y se cerró sola: la pantalla se empuja y algo la saca.
            Secuencia: \(visita.barsSeen.joined(separator: " → "))
            """
        )

        // `.secureTextFields` y no `.textFields`: un `SecureField` no aparece
        // en la segunda colección, y buscarlo ahí da un elemento inexistente
        // que se lee como una pantalla que no cargó.
        let actual = app.secureTextFields["password.current"]
        XCTAssertTrue(
            actual.waitForExistence(timeout: 10),
            "«Contraseña actual» no es direccionable en la pantalla que sí abrió."
        )
        assertNoDecodingFailureVisible(app, screen: "Cambiar la contraseña")

        // El botón no se puede pulsar con el formulario a medias: sin esto, la
        // pantalla invitaría a gastar una petición que no puede funcionar.
        XCTAssertFalse(
            element("password.submit", in: app).isEnabled,
            "el formulario vacío deja enviar"
        )

        // Una actual deliberadamente equivocada, y una nueva que jamás se
        // aplica porque la actual no valida.
        try type("no-es-la-contrasena-de-nadie", into: actual, in: app)
        try type("Rechazada-1234", into: app.secureTextFields["password.new"], in: app)
        try type("Rechazada-1234", into: app.secureTextFields["password.confirm"], in: app)

        // Por `hittableRow`, no por `element`.
        //
        // El botón vive en la última sección del formulario, que es justo donde
        // el teclado y la barra de pestañas lo tapan después de escribir en los
        // tres campos. `isEnabled` decía que sí y el toque se lo comía el
        // teclado: el fallo llegaba veinte segundos después como «el backend
        // rechazó la contraseña y la pantalla no lo dijo», acusando a una
        // pantalla que nunca había recibido el toque.
        guard let enviar = hittableRow("password.submit", in: app) else {
            return XCTFail("«Cambiar la contraseña» no es pulsable: algo lo tapa y no se puede destapar.")
        }
        XCTAssertTrue(enviar.isEnabled, "con los tres campos puestos tiene que dejar enviar")

        // El envío también se REINTENTA, y aquí hace falta decir por qué es
        // seguro.
        //
        // Reintentar una NAVEGACIÓN es inocuo: un toque tragado no deja rastro.
        // Reintentar un ENVÍO no lo es en general — puede escribir dos veces.
        // Lo es en ESTE test y solo en este: la contraseña actual va
        // deliberadamente equivocada, así que ningún intento puede mutar nada.
        // El backend rechaza los N con 422 y la pantalla acaba diciendo lo
        // mismo que diría con uno.
        //
        // **No copiar este patrón a un envío que sí escriba** sin repetir ese
        // razonamiento. Aquí está porque el toque se tragaba: el botón salía
        // habilitado, el toque aterrizaba y no disparaba nada —la misma firma
        // que en el acceso y en la fila del perfil—, y el test acusaba a la app
        // de callar un rechazo que nunca había llegado a pedir.
        let errorEnPantalla = element("password.error", in: app)
        for intento in 0..<3 {
            guard !errorEnPantalla.exists else { break }
            guard enviar.exists, enviar.isEnabled, enviar.isHittable else { break }
            enviar.tap()
            if errorEnPantalla.waitForExistence(timeout: intento == 0 ? 20 : 10) { break }
        }

        // Y el rechazo se CUENTA. Es lo que separa «no ha funcionado» de un
        // botón que se pulsa y no pasa nada.
        let error = element("password.error", in: app)
        XCTAssertTrue(
            error.waitForExistence(timeout: 20),
            "el backend rechazó la contraseña y la pantalla no lo dijo"
        )
        XCTAssertFalse(error.label.isEmpty, "el error existe y está vacío")
    }

    /// Lo que el widget va a leer, comprobado contra datos reales.
    ///
    /// La pantalla de inicio del aspirante era lo único de todo el producto sin
    /// una sola verificación contra staging, y es la superficie que **ven otras
    /// personas**: el widget se instala en la pantalla de inicio y lo lee
    /// cualquiera que mire el teléfono.
    ///
    /// XCUITest no alcanza la vista de una extensión desde el proceso de la
    /// app, y eso es un límite real. Pero lo que puede estar mal no es la
    /// vista: es la instantánea. `PublishedSnapshotProbe` la lee del App Group
    /// —el runner no puede, es otro proceso— y la deja como etiqueta.
    func testWidgetSnapshot() throws {
        let app = launchClean()
        try signIn(app)
        dismissSystemSavePasswordSheet()

        let probe = element("snapshot.published", in: app)
        guard probe.waitForExistence(timeout: 15) else {
            return XCTFail(
                "La sonda de la instantánea no existe. Se expone solo con "
                + "-uitest-redact-secrets, que `launchClean` pasa."
            )
        }

        // **Recién entrado, con la vista rápida apagada por defecto.**
        //
        // Es el estado que el RGPD art. 25.2 exige y el que el proyecto eligió:
        // el widget no enseña el puesto de nadie hasta que la persona lo pide.
        // Si esto dijera «posicion:…» sin que nadie haya tocado el ajuste,
        // sería una fuga en la superficie más visible del producto.
        XCTAssertTrue(
            probe.label == "desactivado" || probe.label == "ausente",
            "recién iniciada la sesión el widget no puede llevar cifras, y lleva «\(probe.label)»"
        )

        // Y ahora la mitad que prueba que el conducto funciona: abrir «Mi
        // posición» publica. Sin esto, lo de arriba pasaría también para una
        // app que no publica nunca.
        guard destinations(in: app).contains("Mi posición") else {
            try skipUnlessTheRoleShouldHaveIt(
                "Mi posición",
                expected: \.hasOwnStanding,
                detail: "Sin posición propia no hay instantánea que publicar."
            )
            return
        }
        XCTAssertTrue(navigate(to: "Mi posición", in: app), "«Mi posición» no llegó a abrirse.")

        // Con la vista rápida apagada solo puede escribirse «desactivado»: el
        // publicador lo respeta por diseño. Lo que se comprueba aquí es que
        // ESCRIBE, no que enseñe cifras.
        let despues = element("snapshot.published", in: app)
        XCTAssertTrue(despues.waitForExistence(timeout: 20))
        XCTAssertNotEqual(
            despues.label, "ausente",
            "abrir «Mi posición» no escribió nada en el App Group: el widget se quedaría en blanco para siempre"
        )
        XCTAssertFalse(
            despues.label.hasPrefix("ilegible"),
            "la instantánea no se puede leer: «\(despues.label)» — el widget mostraría «No hay datos disponibles»"
        )
    }

    /// El sidebar del iPad: ¿se puede navegar por él o no?
    ///
    /// El recorrido general se SALTA este layout citando un límite de XCUITest
    /// —«no acciona la selección de un List de SwiftUI», seis aproximaciones
    /// probadas— y ese salto lleva ahí desde antes de que el sidebar se
    /// reescribiera sobre `DashboardRouter`.
    ///
    /// Se vuelve a intentar por una razón concreta: hoy un «límite documentado
    /// de la herramienta» estaba tapando un defecto real de la app —la tabla
    /// del instructor no navegaba y la explicación cómoda encajaba— y una nota
    /// heredada no es una medición.
    ///
    /// Distingue las dos causas, que es lo único que hace útil el intento: si
    /// la fila no tiene marco válido, es direccionamiento y se dice; si lo
    /// tiene y aun así no mueve el panel, el sidebar no navega y eso es de la
    /// app. En iPad este sidebar es la vía principal de todo, así que la
    /// diferencia importa.
    func testIPadSidebar() throws {
        let app = launchClean()
        try signIn(app)
        dismissSystemSavePasswordSheet()

        guard !app.tabBars.firstMatch.waitForExistence(timeout: 10) else {
            throw XCTSkip("Layout compacto: este test es del sidebar, que solo existe en ancho regular.")
        }

        // «Perfil» la tiene todo rol, y su panel de detalle lleva un título
        // propio con el que se reconoce sin depender de los datos.
        let perfil = element("sidebar.perfil", in: app)
        XCTAssertTrue(
            perfil.waitForExistence(timeout: 15),
            "El sidebar no ofrece «Perfil»: la sesión no llegó a abrirse."
        )

        // El caso de control, que antes no lo era.
        //
        // Esto medía el marco —eso sí— y a continuación afirmaba un
        // diagnóstico que nadie había comprobado: «es direccionamiento de
        // XCUITest, no la app». Un marco de cero también lo produce un sidebar
        // que la app no llegó a maquetar, y esa sería la app.
        //
        // La distinción no es teórica: en este mismo archivo había otro salto
        // que culpaba a XCUITest por no poder direccionar una celda, y resultó
        // ser arrastre de un toque tragado en el acceso. Al arreglar la causa,
        // aquel test dejó de saltarse. Una hipótesis con antigüedad no es un
        // hecho, y la antigüedad es justo lo que la hace parecer uno.
        //
        // El control: si las OTRAS filas del sidebar sí tienen marco, lo de
        // «Perfil» es direccionamiento. Si ninguna lo tiene, el sidebar no se
        // maquetó y eso hay que decirlo como defecto, no saltárselo.
        let marco = perfil.frame
        if marco.width <= 0 || marco.height <= 0 {
            // Las cuatro restantes. Se construyen igual que en la app, con
            // `SidebarSection.rawValue`; `miPosicion` y `miProgreso` solo
            // existen para el aspirante, y por eso se filtra por `exists`.
            let otras = ["sidebar.panel", "sidebar.convocatorias",
                         "sidebar.miPosicion", "sidebar.miProgreso"]
                .map { element($0, in: app) }
                .filter { $0.exists }
            let algunaConMarco = otras.contains { $0.frame.width > 0 && $0.frame.height > 0 }

            XCTAssertTrue(
                algunaConMarco,
                "NINGUNA fila del sidebar tiene marco, ni «Perfil» ni las otras "
                + "\(otras.count). Eso no es direccionamiento de XCUITest: el "
                + "sidebar del iPad no se está maquetando."
            )

            throw XCTSkip(
                "La fila «sidebar.perfil» existe sin marco válido (\(marco)) pero "
                + "otras filas del sidebar SÍ lo tienen, así que es direccionamiento "
                + "de XCUITest y no la app —comprobado, no supuesto—. SIN cubrir: la "
                + "navegación del sidebar."
            )
        }

        perfil.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let abrio = app.navigationBars["Perfil"].waitForExistence(timeout: 15)
        capture(app, named: "30-ipad-sidebar-perfil")

        XCTAssertTrue(
            abrio,
            "La fila «Perfil» tiene marco válido (\(marco)) y su toque no mueve el "
            + "panel de detalle. Con marco, esto NO es direccionamiento: el sidebar "
            + "del iPad no navega, y en ese layout es la vía principal de todo."
        )

        assertNoDecodingFailureVisible(app, screen: "Perfil en iPad")
        assertNoVerdictVisible(app, screen: "Perfil en iPad")
    }

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

        // En los dos layouts: pestaña en compacto, fila del sidebar en regular.
        // `navigate` sabe hacer las dos cosas — y ahora que las filas del
        // sidebar son enlaces de verdad, la segunda funciona.
        guard destinations(in: app).contains("Mi progreso") else {
            try skipUnlessTheRoleShouldHaveIt(
                "Mi progreso",
                expected: \.hasOwnStanding,
                detail: "Solo el aspirante tiene progreso propio."
            )
            return
        }

        XCTAssertTrue(
            navigate(to: "Mi progreso", in: app),
            "«Mi progreso» está en los destinos y no se llegó a abrir."
        )

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
        // Primero se PREGUNTA, y solo si hay algo se enumera.
        //
        // `allElementsBoundByIndex` hace una ida y vuelta POR ELEMENTO. Esta
        // comprobación enumeraba hasta 300 siempre, nada más que para saber si
        // existía una fila «No evaluado» —que en la mayoría de pantallas no
        // existe—, y acababa en `return` habiendo pagado las 300.
        //
        // Medido en una vuelta del recorrido en iPad: 687 consultas de elemento
        // y unos cinco minutos del test gastados en enumerar. Un predicado lo
        // resuelve el lado del simulador en UNA consulta.
        //
        // La enumeración completa sigue estando: solo se paga cuando hay una
        // fila que de verdad hay que explicar. Mismo comportamiento, mismo
        // fallo cuando toca fallar.
        let sinValor = app.staticTexts.matching(
            NSPredicate(format: "label IN %@", ["No evaluado", "Sin dato"])
        )
        guard sinValor.firstMatch.exists else { return }

        let labels = app.staticTexts.allElementsBoundByIndex
            .prefix(300)
            .compactMap { $0.exists ? $0.label : nil }

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
            "«Resultados» no pintó la cabecera de su tabla. "
            + "Barras: \(app.navigationBars.allElementsBoundByIndex.compactMap { $0.exists ? $0.identifier : nil }). "
            + "Textos visibles: \(app.staticTexts.allElementsBoundByIndex.prefix(25).compactMap { $0.exists ? $0.label : nil })."
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
            // La ausencia del enlace es INFORMACIÓN, no silencio.
            //
            // Este control vivía dentro del `if`: si el nombre no aparecía, no
            // se comprobaba nada y el salto se quedaba sin examinar, con la
            // misma cara que si el control hubiera pasado.
            XCTAssertTrue(
                aspirante.waitForExistence(timeout: 5),
                "La matriz no ofrece ni celdas direccionables ni el enlace del "
                + "nombre, así que no hay forma de comprobar si el contenedor "
                + "navega. Esta corrida NO puede decidir si es XCUITest o la app."
            )
            if aspirante.exists {
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
            // Sidebar: se navega primero, igual que con pestañas.
            //
            // Antes no se navegaba porque «la selección del sidebar no es
            // automatizable», y se buscaban filas en el panel que hubiera
            // puesto. Sí es automatizable: lo que faltaba era el
            // `NavigationLink(value:)` en las filas del sidebar de la app.
            if navigate(to: "Convocatorias", in: app),
               let row = hittableRow("convocatorias.row", in: app) {
                return row
            }
            // Y si no, la fila que el panel del instructor tenga a mano: él
            // aterriza ahí y su tarjeta lleva su propio identificador.
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
    /// Lo que pasó con una barra de navegación durante una espera.
    ///
    /// Existe porque «no apareció» y «apareció y se fue» son dos defectos
    /// distintos con arreglos opuestos, y una aserción sobre el estado final
    /// los cuenta como el mismo.
    private struct NavigationBarVisit {
        var everAppeared = false
        var stillThere = false
        var barsSeen: [String] = []
    }

    /// Muestrea qué barra de navegación hay, en vez de esperar a una.
    private func sampleNavigationBar(
        _ title: String,
        in app: XCUIApplication,
        seconds: Int
    ) -> NavigationBarVisit {
        var visit = NavigationBarVisit()
        var previous = ""

        for _ in 0..<(seconds * 2) {
            let bar = app.navigationBars[title]
            // El TÍTULO, no el identificador.
            //
            // La primera versión leía `.identifier`, que en una barra de
            // SwiftUI viene vacío salvo que alguien lo ponga: el muestreo
            // informó «Convocatorias» —la única con identificador, de una
            // pestaña montada— estando la app en Perfil, y esa lectura mandó
            // la investigación a la pantalla equivocada.
            let campos = app.secureTextFields.allElementsBoundByIndex
                .map(\.identifier).filter { !$0.isEmpty }
            let current = (app.navigationBars.allElementsBoundByIndex
                .map { $0.identifier.isEmpty ? $0.label : $0.identifier }
                .filter { !$0.isEmpty }
                + campos.map { "campo:\($0)" })
                .joined(separator: "+")

            if current != previous {
                visit.barsSeen.append(current.isEmpty ? "(ninguna)" : current)
                previous = current
            }

            if bar.exists {
                visit.everAppeared = true
                visit.stillThere = true
            } else if visit.everAppeared {
                visit.stillThere = false
            }

            // Una vez vista y estable medio segundo, no hace falta seguir.
            if visit.everAppeared, visit.stillThere, visit.barsSeen.count > 1 { break }
            Thread.sleep(forTimeInterval: 0.5)
        }

        return visit
    }

    private func hittableRow(_ identifier: String, in app: XCUIApplication) -> XCUIElement? {
        for attempt in 0..<6 {
            // TODAS las coincidencias, no `firstMatch`.
            //
            // Una lista de intentos tiene muchas filas con el mismo
            // identificador, y `firstMatch` se queda con una sola: si esa cae
            // debajo de la barra o encima del borde, seis gestos después
            // seguía sin servir y el helper se rendía sobre una pantalla llena
            // de filas perfectamente tocables. Vale cualquiera que se pueda
            // tocar; lo que se prueba después es adónde lleva, no cuál era.
            let filas = app.descendants(matching: .any).matching(identifier: identifier)

            if filas.firstMatch.waitForExistence(timeout: attempt == 0 ? 8 : 2) {
                for fila in filas.allElementsBoundByIndex {
                    guard fila.isHittable, isClearOfTheBottomChrome(fila, in: app) else { continue }
                    if hasStoppedMoving(fila) { return fila }
                }
            }

            app.swipeUp()
        }
        return nil
    }

    /// Toca la fila hasta que llega algo que solo existe en el destino.
    ///
    /// La llegada se pasa como elemento y no como título de barra: hay
    /// pantallas cuyo título depende de los datos —el detalle de un intento— y
    /// ahí lo único reconocible es un control propio suyo.
    @discardableResult
    private func tapUntilArriving(
        _ row: XCUIElement,
        at destination: XCUIElement,
        attempts: Int = 4,
        timeout: TimeInterval = 6
    ) -> Bool {
        for _ in 0..<attempts {
            // Si ya se llegó, no se vuelve a tocar.
            if destination.exists { return true }

            // La fila que desaparece es señal de que el toque SÍ funcionó: se
            // dejó de estar en la pantalla que la contenía. Rendirse aquí
            // devolvía «no llegó» sobre un destino que todavía estaba
            // cargando, que es acusar a la app de lo contrario de lo que pasó.
            guard row.exists, row.isHittable else { break }

            row.tap()
            if destination.waitForExistence(timeout: timeout) { return true }
        }

        // Una última espera completa, por el caso de arriba.
        return destination.waitForExistence(timeout: timeout)
    }

    /// El mismo reintento cuando la llegada SÍ es una barra con nombre fijo.
    private func tapUntilPushed(
        _ row: XCUIElement,
        destination: String,
        in app: XCUIApplication,
        attempts: Int = 4
    ) {
        tapUntilArriving(row, at: app.navigationBars[destination], attempts: attempts)
    }

    /// Si la fila ha dejado de moverse.
    ///
    /// **`swipeUp` tiene inercia.** El `Form` sigue desplazándose después del
    /// gesto, y `isHittable` y `frame` se leen en pleno vuelo: el toque se
    /// calcula con la posición de hace un instante y aterriza donde la fila
    /// **estaba**. No falla siempre, y ahí está lo peor — falla según cuántos
    /// gestos hicieran falta, así que la fila de arriba pasa y la de abajo no,
    /// y parece un defecto de esa pantalla en concreto.
    ///
    /// Dos lecturas iguales separadas por un respiro. No es una espera fija
    /// disfrazada: si la vista ya está quieta, la primera comparación acierta.
    private func hasStoppedMoving(_ element: XCUIElement) -> Bool {
        var previous = element.frame

        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.15)
            let current = element.frame
            if current == previous { return true }
            previous = current
        }
        return false
    }

    /// Si el centro del elemento queda por ENCIMA de lo que el sistema dibuja
    /// abajo: la barra de pestañas y el teclado.
    ///
    /// **`isHittable` no lo dice.** Lo calcula del marco del propio elemento y
    /// no de lo que hay dibujado encima, así que una fila tapada por la barra
    /// flotante de iOS 26 se declara tocable, el toque se lo come la barra, y
    /// el fallo aparece veinte segundos después como «la pantalla no se
    /// empujó»: un defecto de la app que no existía.
    ///
    /// Costó una investigación entera. La fila de la contraseña medía
    /// `y 785…837` en una pantalla de 874 —justo debajo de la barra— mientras
    /// la del PIN, dos filas más arriba, pasaba. Mismo helper, mismo toque, y
    /// el que fallaba era el de abajo.
    ///
    /// El teclado es el mismo problema con otro ocultador, y aparece justo
    /// donde más duele: el botón de enviar vive al final del formulario, que es
    /// exactamente donde el teclado lo tapa después de escribir.
    ///
    /// Es el patrón de siempre en este archivo: **existir no es poder
    /// tocarse**, y ahora tampoco «ser tocable» lo es.
    private func isClearOfTheBottomChrome(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        let center = element.frame.midY

        for chrome in [app.tabBars.firstMatch, app.keyboards.firstMatch] where chrome.exists {
            // Un marco vacío no tapa nada. XCUITest deja a veces un teclado
            // «existente» de altura cero: tomado en serio, su `minY` es 0 y
            // descarta TODAS las filas de la pantalla.
            let frame = chrome.frame
            guard frame.height > 1 else { continue }
            if center >= frame.minY { return false }
        }
        return true
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
        // La segunda bandera tapa las credenciales mientras corre el test: el
        // PIN no llega a dibujarse, así que no hay nada sensible que capturar
        // ni cuando el test pasa ni cuando falla. Ver `SecretRedaction`.
        app.launchArguments += ["-uitest-reset-session", "-uitest-redact-secrets"]
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

        // El toque se REPITE hasta que la pantalla de acceso se va.
        //
        // Medido, no supuesto: cuando esto falla, el diagnóstico dice
        // «submit existe=true activo=true rótulo=Iniciar sesión · email
        // vacío=false · hay indicador de progreso=false». Botón visible,
        // habilitado, sin cuenta atrás del límite, campos llenos y **ninguna
        // petición en vuelo**. Es decir: el toque aterrizó y no disparó nada.
        //
        // Es la tercera vez esta semana con la misma forma —la fila del perfil
        // bajo la barra flotante, el botón de enviar bajo el teclado— y este
        // era el único toque del recorrido que no pasaba por la disciplina.
        // Repetirlo es seguro: uno tragado no deja rastro, y en cuanto la
        // pantalla se va, para.
        // Un toque, y el reintento SOLO si hizo falta.
        //
        // La versión anterior metía una espera con predicado dentro del bucle,
        // así que el camino bueno —el que va a ocurrir casi siempre— pagaba
        // consultas de más. En iPad eso reventó: la jerarquía de accesibilidad
        // es grande, capturarla costaba 14 s y la consulta agotaba el tiempo.
        // Un arreglo que encarece el caso normal para cubrir el raro está mal
        // hecho aunque cubra el raro.
        //
        // Ahora el coste del reintento lo paga solo quien lo necesita: se toca
        // una vez, se espera como siempre, y únicamente si el formulario sigue
        // ahí se vuelve a tocar. Cuando el acceso funciona a la primera, esto
        // hace exactamente lo mismo que hacía antes de tocarlo nada.
        app.buttons["login.submit"].tap()

        // The signal is the login field going away, not a tab bar arriving.
        //
        // On iPad the app lays itself out as a sidebar and there IS no tab bar,
        // so waiting for one failed 30 s after a sign-in that had actually
        // worked — the dashboard was on screen behind the system sheet. Only
        // running on iPad showed it.
        func esperaAQueSeVaya(_ segundos: TimeInterval) -> Bool {
            let gone = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: email
            )
            return XCTWaiter.wait(for: [gone], timeout: segundos) == .completed
        }

        // El reintento vive AQUÍ, en el camino de fallo.
        //
        // Cuando el acceso funciona, la primera espera lo resuelve y esto no
        // cuesta nada. Cuando no, se vuelve a tocar: el diagnóstico de este
        // mismo fallo decía «botón habilitado, campos llenos, ninguna petición
        // en vuelo», o sea que el toque aterrizó sin disparar nada, y ahí sí
        // hace falta insistir.
        var entró = esperaAQueSeVaya(30)
        var reintentos = 0
        while !entró, reintentos < 2, email.exists {
            let boton = app.buttons["login.submit"]
            guard boton.exists, boton.isHittable else { break }
            boton.tap()
            entró = esperaAQueSeVaya(12)
            reintentos += 1
        }

        guard entró else {
            capture(app, named: "00-login-fallido")
            // El mensaje que la pantalla está dando, no «mira la captura».
            //
            // «No session after 30 s» describe el síntoma y calla la causa, así
            // que las tres veces que ha salido hoy lo he atribuido a contención
            // de la máquina —que es lo que era dos de ellas— sin poder
            // distinguirlo de un límite de intentos, unas credenciales
            // caducadas o el backend caído. El error lo pone la app en pantalla
            // con su identificador; leerlo cuesta una línea.
            let dicho = element("login.error", in: app)
            let motivo = dicho.exists ? dicho.label : "la pantalla no muestra ningún error"

            // Y el ESTADO del formulario, no solo lo que dice.
            //
            // «Sin error y sin navegar» encaja con dos cosas incompatibles: el
            // toque no hizo nada —botón deshabilitado, por ejemplo por la
            // cuenta atrás del límite de intentos— o la petición se quedó
            // colgada. El mensaje anterior no las distinguía, y sin
            // distinguirlas no hay diagnóstico posible: una se arregla en el
            // test y la otra en la app.
            //
            // Nada de contenido: los campos llevan credenciales. Solo si están
            // vacíos, que es lo único que hace falta saber de ellos.
            let enviar = element("login.submit", in: app)
            let estado = "submit existe=\(enviar.exists) activo=\(enviar.exists ? String(enviar.isEnabled) : "—")"
                + " rótulo=«\(enviar.exists ? enviar.label : "—")»"
                + " · email vacío=\(email.value as? String == "" || email.value == nil)"
                + " · hay indicador de progreso=\(app.activityIndicators.firstMatch.exists)"


            return XCTFail("Sin sesión tras 30 s. La pantalla dice: «\(motivo)». \(estado)")
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
        // «Mi progreso» faltaba en esta lista, así que en iPad el recorrido
        // nunca la visitaba: una pantalla entera del aspirante, invisible para
        // los tests en la mitad de las plataformas soportadas.
        return ["Panel", "Convocatorias", "Mi posición", "Mi progreso", "Perfil"]
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
