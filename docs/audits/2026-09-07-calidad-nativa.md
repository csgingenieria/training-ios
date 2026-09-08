# Auditoría de calidad nativa del cliente iOS — 2026-09-07

**Alcance:** el cliente tal como está en `main` (`7439b90`), auditado contra la meta «paridad total del portal del aspirante, nativa y de alta calidad». Cinco lentes independientes (accesibilidad, iPad y layout adaptativo, estados y resiliencia, consistencia visual y paridad de información, oficio nativo), cada hallazgo importante o bloqueante sometido a un escéptico independiente que intentó refutarlo. 63 agentes, 371 lecturas de código.

**Regla del backlog:** todo lo que aparece es hacible **hoy, sin cambios de backend**. Lo que necesita endpoint está al final, en una línea, y lo cubre el pedido `docs/api-needs/2026-09-07-portal-aspirante.md`.

**Idioma:** el marco de este documento está en castellano; el texto de veredicto, fortalezas y hallazgos se conserva en el inglés técnico en que lo produjeron los auditores, sin traducir, para no introducir deriva entre lo que se verificó y lo que se lee.

**Aviso de archivos en edición:** los ítems marcados *provisional* citan `Features/Standing/StandingView.swift` o `Features/Convocatorias/ConvocatoriaDetailView.swift`, que otra sesión estaba modificando durante la auditoría. Las líneas citadas son de `HEAD`; re-verificar contra la versión final antes de actuar.

---

## Veredicto

The client is structurally sound and honest: typed loading/loaded/notFound/error states on every screen, formal Castilian copy pinned by tests, a widget that carries no credentials and degrades by age rather than lying, a design system with Dynamic Type baked into every font role, and DTO/enum freeze tests that catch contract drift. That is a better base than most "first release" apps. But it is not yet "nativo y espectacular", and two things are incident-grade today: the STUDENT home tab («Mi posición») can never recover from a single failed load because `errorMessage` is never reset (ST-01), and the forbidden word «plaza» sits under every candidate's position in two screens (ST-02/VOCAB-02/NC-01). Behind those, the systemic gaps are (1) refresh semantics — every reload blanks the screen and a failed pull-to-refresh replaces good data with an error, with no last-known value and no data age anywhere in the app; (2) recovery affordances — embedded error cards and empty states have no button and pull-to-refresh is inert on them; (3) the iPad story is a split-vs-tab switch and nothing else (no shared router, no readable width, state lost on size-class change); (4) craft — zero animation beyond the button press, zero haptics, widget palette/fonts detached from the app, login form deaf to the keyboard. Roughly 20 of the 26 important items are S or M and client-only; a focused week closes the blockers, the refresh/recovery class, and the login/iPad basics. The remaining "spectacular" work (per-route grid, motion, skeletons, offline store) is real but optional for parity. Web-parity gaps that need the API (attempt date in detail, org name, per-event deduction, route catalog, GPS, PDF) are listed separately.

---

## Lo que ya está bien (no reescribir)

- Typed error copy in formal Castilian, pinned by tests: Dobacksoft Training/Core/API/APIError.swift:25-40 and Dobacksoft TrainingTests/Services/APIErrorTests.swift:1-60 (register explicitly tested, no voseo).
- Network seam for TDD already exists: Dobacksoft Training/Core/API/TrainingAPI.swift:13 protocol + Dobacksoft TrainingTests/Helpers/FakeTrainingAPI.swift:10 scripted actor with per-endpoint result queues and recorded calls.
- AuthSession keeps tokens on transport failure and only logs out on 401: Dobacksoft Training/Core/Auth/AuthSession.swift:55-61, covered by AuthSessionTests.swift:125-137.
- Status vocabulary centralised and GDPR-scanned: Dobacksoft Training/Core/Models/StatusVocabulary.swift:23-65; StatusVocabularyTests.swift:78 bans apto/suspens/aprob/corte/plaza/cupo in labels; GradeFinalityTests.swift:60 and GradeCompositionTests.swift:63 do the same.
- Grade finality and not-found reasons are typed, not stringly: Dobacksoft Training/Core/Models/GradeFinality.swift:57-68 (scoreLabel/note) and NotFoundReason.swift:36-63 (notEnrolled / noStandingYet / resourceMissing with own copy).
- Contract drift is a compile-time event: Dobacksoft TrainingTests/DTOTests/ContractEnumFreezeTests.swift:18-40 freezes backend enums with a documented rationale.
- Widget architecture is exemplary: single writer Shared/SnapshotPublisher.swift:4-63, no credentials/no network, off by default citing RGPD art. 25.2 (:18-21), error loads never overwrite the last good snapshot (:66-68); SharedSnapshot/SnapshotFreshness.swift:17-20 ages 6h/48h from capturedAt; SnapshotStore.swift:20-38 types read failures; figures `.privacySensitive()` (Dobacksoft_Training_Widgets.swift:198,213,239,248,266); snapshot deliberately omits ids, name, plaza, cupo (StandingSnapshot.swift:12-15).
- Design tokens with Dynamic Type everywhere: Shared/Theme/Theme.swift:21-89 (spacing/radius/shadow/motion), Theme+Typography.swift:59-75 every custom font is `relativeTo:` a text style; colour assets carry dark variants (Assets.xcassets/Colors/Paper.colorset with luminosity dark).
- Scores are never coloured as a verdict: Shared/Theme/DataQuality+Badge.swift:15-27 bans score colour; ResultadosView.swift:267-269 keeps positions uncoloured.
- Login is instrumented for UI tests: LoginView.swift:37,44,73 (`login.email`, `login.password`, `login.submit`) and error text has an explicit VoiceOver label (:57).
- ConvocatoriasListView covers loading / empty / loaded / search-empty / scope-empty with «Ver todas» / error with «Reintentar» / pull-to-refresh: ConvocatoriasListView.swift:39-77,103.
- StandingCard hero has a combined VoiceOver sentence «Puesto N de M» (StandingView.swift HEAD:144) and a composition block with ProgressView + «Media de lo conducido» (HEAD:207-257); practice-route disclaimer wording is GDPR-neutral (HEAD:577).
- AttemptDetailView explains rounding and shows scoreRaw when it differs (AttemptDetailView.swift:263-271), and breakdown rows are one VoiceOver element (:316).
- iPad already switches to NavigationSplitView with identified sidebar rows: DashboardView.swift:14-18, 69-101, 118-120 (`sidebar.<id>` identifiers, isButton trait).
- Staging walkthrough UI test exists and already bans «PLAZA ASIGNADA» and checks the student path end to end: Dobacksoft TrainingUITests/StagingWalkthroughUITests.swift:53,120,484.

---

## Backlog priorizado

57 ítems — bloqueantes 2, importantes 26, menores 29. Esfuerzo: S 42 · M 13 · L 2 (S = menos de una hora, M = media jornada, L = una jornada o más).

| # | Est. | Sev. | Esf. | Ítem | Lentes |
|---|------|------|------|------|--------|
| 1 | ✅ | blocker | S | «Mi posición» tab: reset errorMessage on load so Reintentar/pull-to-refresh can recover *(provisional)* | states |
| 2 | ✅ | blocker | S | Purge forbidden-root UI strings («asignación de plaza», «tolerancia admitida») and add a UI-copy freeze test *(provisional)* | states, ipad, native-craft, visual |
| 3 | ◐ | important | M | Keep the last good data on refresh: no blanking to a spinner, no error replacing loaded content *(provisional)* | states, native-craft |
| 4 | ✅ | important | S | Embedded standing/attempts error cards get a heading, an icon and a per-section «Reintentar» *(provisional)* | states, accessibility |
| 5 | ◐ | important | S | Empty states («Sin convocatorias», «Todavía no está inscrito») are refreshable and offer «Actualizar» *(provisional)* | native-craft |
| 6 | ✅ | important | M | Offline or slow launch: tell the candidate their session is intact instead of dropping them on the login form | states |
| 7 | ✅ | important | S | Forced logout explains itself: «Su sesión ha caducado por seguridad» | states |
| 8 | ✅ | important | S | Login form: focus chain, submit-on-return, and VoiceOver announcement of the error | accessibility, ipad, native-craft |
| 9 | ✅ | important | S | Login layout: cap the form at 420 pt and make it scroll so the button survives landscape/keyboard/large text | ipad |
| 10 | ✅ | important | S | Add an OnBrand colorset so primary buttons and selected chips keep ≥4.5:1 contrast in dark mode *(provisional)* | accessibility, visual |
| 11 | ✅ | important | S | «Mi posición» names the convocatoria and its closing date; «activas» count filtered or dropped *(provisional)* | visual, states |
| 12 | ✅ | important | S | Align the provisional-results legal notice with the portal and show it on the attempt detail *(provisional)* | visual |
| 13 | ✅ | important | S | Missing score is stated, not implied: «Sin nota» in the row and «Nota no disponible» hero in the detail *(provisional)* | states |
| 14 | ✅ | important | S | Attempt detail shows the attempt date (threaded from the list, no API change) *(provisional)* | visual |
| 15 | — | important | S | Show the grading gravity of each event (Leve / Moderada / Grave) as a badge | visual |
| 16 | ✅ | important | M | Per-route progress grid («Sus recorridos») with best grade, «Pendiente» and an «Actual» badge on the counting attempt *(provisional)* | visual |
| 17 | ✅ | important | S | One spoken and visible scale for grades: «8,5 sobre 10» for VoiceOver, «/10» caption on the standing score, one hero element *(provisional)* | accessibility, visual |
| 18 | ✅ | important | S | Translate the role: «Aspirante» / «Instructor» / «Administración» instead of STUDENT/Student; hide the organisation UUID | accessibility, visual |
| 19 | — | important | S | «Filtros» menu and «Restablecer filtros»: 44 pt targets and announced active state *(provisional)* | accessibility |
| 20 | ✅ | important | M | Refresh on return to foreground and show «Actualizado a las HH:mm» on data screens *(provisional)* | native-craft |
| 21 | ✅ | important | M | Dashboard router: one shared section + NavigationPath per section for TabView and sidebar | ipad |
| 22 | ✅ | important | M | Widget deep-links to «Mi posición»; «caducado» copy names the screen that refreshes it | states, native-craft, ipad |
| 23 | ✅ | important | M | Readable-width cap (680 pt) for every ScrollView content column on iPad *(provisional)* | ipad |
| 24 | ✅ | important | S | Widget: text styles instead of fixed 34/22/9 pt, and freshness note in the VoiceOver label | accessibility |
| 25 | ✅ | important | S | Widget palette follows dark mode: colorsets in the widget catalog instead of light-only hex literals | native-craft, accessibility, visual |
| 26 | — | important | M | Animate state changes with the existing Theme.motion tokens *(provisional)* | native-craft |
| 27 | — | important | L | Last-known data store with data age for convocatorias, standing and attempts *(provisional)* | states |
| 28 | — | minor | S | Error copy that says what to do: fixed formal sentences for 5xx/422/decoding/unexpected and «No se ha podido cargar» titles *(provisional)* | states |
| 29 | — | minor | S | Cancelled requests are not «No se ha podido conectar»: rethrow cancellation and guard ViewModel state *(provisional)* | states |
| 30 | — | minor | S | Convocatoria chips: 44 pt height, isSelected trait, animated selection, selected chip scrolled into view *(provisional)* | accessibility, native-craft |
| 31 | — | minor | S | CardButtonStyle with press highlight and iPad pointer hover for every NavigationLink card/row *(provisional)* | ipad |
| 32 | — | minor | S | Haptics on login result and chip selection via .sensoryFeedback *(provisional)* | native-craft |
| 33 | — | minor | S | Per-row progress bar in the score breakdown (web parity), guarded by max > 0 | visual |
| 34 | ◐ | minor | S | Share sheets use UI labels, not enum codes, and carry a SharePreview *(provisional)* | visual, native-craft |
| 35 | ✅ | minor | S | One noun for the person: «aspirante» (drop «candidatos» / «alumno» in STUDENT-facing copy) *(provisional)* | visual |
| 36 | — | minor | S | Show the route code next to its name in attempt rows and detail *(provisional)* | visual |
| 37 | — | minor | S | Web KPIs from data already loaded: «Último intento», «Mejor recorrido · A mejorar» *(provisional)* | visual |
| 38 | — | minor | M | Redacted skeletons instead of spinner + caption, with a slow-network hint after 4 s *(provisional)* | states, native-craft |
| 39 | — | minor | M | Semantic numeric roles in Theme+Typography (metricValue / metricValueLarge / scoreHero) *(provisional)* | visual |
| 40 | — | minor | M | Redact content in the app switcher; optional Face ID lock toggle | native-craft |
| 41 | — | minor | S | Rate-limit countdown disables the login button until retryAfter elapses | states |
| 42 | — | minor | S | Perfil «Estado del servidor» row: short value, detail in footer, tappable to re-check | states |
| 43 | — | minor | S | Toolbar «Actualizar» (⌘R) on root screens and ⌘1-4 section shortcuts on iPad *(provisional)* | ipad |
| 44 | — | minor | S | Context menus on convocatoria and attempt rows (share, open «Mi posición») *(provisional)* | native-craft |
| 45 | — | minor | S | Anchor the logout confirmationDialog to the button so the iPad popover points at it | ipad |
| 46 | — | minor | S | Launch and Login use Theme tokens (themed text field style, muted caption, scaled icon) | visual |
| 47 | — | minor | S | Convocatoria header card: explicit VoiceOver sentence and no lineLimit at accessibility sizes *(provisional)* | accessibility |
| 48 | — | minor | M | Metric rows stack vertically at accessibility text sizes (AnyLayout), no fixed-height dividers *(provisional)* | accessibility |
| 49 | — | minor | S | Widget uses the app's Fraunces/Inter via shared font factories | visual |
| 50 | — | minor | S | DisclosureChevron component and a 2 pt spacing token (chevron/spacing literals) *(provisional)* | visual |
| 51 | — | minor | S | Convocatorias in regular width: adaptive two-column grid of cards | ipad |
| 52 | — | minor | S | App Shortcut «Ver mi posición» once the deep link exists | native-craft |
| 53 | — | minor | L | Republish the widget snapshot on any app foreground (BGAppRefresh optional later) | native-craft |
| 54 | ✅ | important | M | MANAGER · Resultados table: scale column widths with Dynamic Type and grow the name column into the iPad pane | accessibility, ipad |
| 55 | — | minor | S | MANAGER · Resultados VoiceOver: hide duplicate position cell, label «#» as «Puesto», hide «·» separators, «sin dato» for «—» | accessibility |
| 56 | — | minor | S | MANAGER · Panel polish: adaptive KPI grid, 44 pt search-clear button, hide «Ver todas» in regular width | ipad, accessibility |
| 57 | — | minor | S | Project hygiene: remove Apple Watch (device family 4) from the four test configurations | ipad |


### Estado (verificado el 2026-09-08)

`✅` cerrado · `◐` parcial · `—` abierto. **Verificado leyendo el código, no de
memoria**: el bloqueante #1 se dio por cerrado durante un día entero de trabajo
encima, y seguía abierto — `load()` nunca limpiaba `errorMessage` y la rama del
error iba antes que la del contenido, así que un fallo pasajero dejaba muerta
la pantalla principal del aspirante. `RefreshTicker` (#20) lo empeoró antes de
que nadie lo notara: al recargar solo al volver del fondo, una cobertura mala
podía dejarla muerta sin que el aspirante tocara nada.

Por eso esta tabla lleva estado ahora. Llevarlo en la conversación y en los
mensajes de commit no sobrevive a una sesión.

**Cerrados: 23 · parciales: 3 · abiertos: 31.**

Los parciales, con lo que falta de cada uno:

- **#3** — hecho en standing/progreso/convocatorias; el detalle del intento sigue vaciándose
- **#5** — hecho en convocatorias; falta el vacío de «Mi posición»
- **#34** — rótulos sí (fdb368a); falta el SharePreview

Abiertos de severidad *important*: **#15** (gravedad del evento como insignia,
`sensorSeverity` decodificado y sin pintar), **#19** (objetivos de 44 pt en el
menú de filtros), **#26** (animaciones con los tokens de `Theme.motion`) y
**#27** (almacén de último dato conocido). El resto son los 27 menores.

### Verificado contra staging (2026-09-08)

Un ✅ de la tabla significa «el código hace lo que dice y hay un test que lo
fija». Lo de abajo es lo otro: **visto funcionando con datos reales de
CMadrid**. Se corre con `scripts/staging-walkthrough.sh student|manager`, que
lee las credenciales del Keychain y exige el rol.

|            | iPhone 17 Pro | iPad Pro 11" (M5) |
|------------|---------------|-------------------|
| Aspirante  | ✅ 3 de 3 + 1 salto correcto | ✅ 4 de 4 + 1 salto correcto |
| Instructor | ✅ 2 de 2 + 2 saltos correctos | ✅ 3 de 3 + 2 saltos correctos |

Cubierto: acceso, el recorrido de todos los destinos del rol, «Mi posición» →
detalle del intento, «Mi progreso» → ficha del recorrido → vuelta → mapa,
«Resultados» → celda → detalle, y el sidebar del iPad. Con la aserción, en cada
pantalla, de que no hay fallo de decodificación visible ni ningún veredicto.

Los saltos son solo los de rol —un aspirante no tiene «Resultados», un
instructor no tiene «Mi posición» ni «Mi progreso»— y con `STAGING_ROLE`
declarado **la pantalla que ese rol posee no puede saltarse**: falla. Así que
ningún verde de esta tabla tapa una pantalla sin visitar.

**Esto encontró cuatro defectos que la auditoría no podía ver**, porque la
auditoría leyó código: el mapa del intento no decodificaba (`severity` llega
como texto y un evento hundía el payload entero), el router descartaba
pantallas al reconciliar un binding, el destino de navegación de «Mi posición»
vivía dentro de una rama condicional, y el sidebar del iPad no navegaba para
nadie.

**Sin cubrir todavía:** el widget, «Mi PIN de tablet», el cambio de contraseña,
y el detalle del intento por el camino del instructor en iPhone (la matriz
scrollea en dos ejes y ahí el direccionamiento de celdas sí es frágil).

### Detalle

#### 1. «Mi posición» tab: reset errorMessage on load so Reintentar/pull-to-refresh can recover — *provisional*

**Severidad:** blocker · **Esfuerzo:** S · **Lentes:** states

**Archivos:** `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** After one transient failure the main STUDENT screen shows «Error … Reintentar» forever: `load()` fills `convocatorias` but never clears `errorMessage`, and the error branch wins over the loaded branch (HEAD:304-311, 446-461). The only way out is killing the app.

**Cambio propuesto:** PROVISIONAL — file is being edited by another session; coordinate before touching. Extract `MyStandingTabView`'s ad-hoc `isLoading/errorMessage/convocatorias` into a `MyStandingTabViewModel` with the same mutually exclusive `State` enum (.loading/.loaded([ConvocatoriaSummaryDTO])/.empty/.error(String)) used by `StandingViewModel`, injecting `api: TrainingAPI = APIClient.shared`. Minimal alternative if the refactor must wait: first line of `load()` sets `errorMessage = nil`.

**Test primero:** Dobacksoft TrainingTests/Features/MyStandingTabViewModelTests.swift (Swift Testing): extend FakeTrainingAPI with `myConvocatoriasResults` queue; script `[.failure(APIError.transport(URLError(.timedOut))), .success([conv])]`; call `load()` twice; `#expect(vm.state == .loaded([conv]))` — currently impossible to write because the state lives in the View, which is the point.

#### 2. Purge forbidden-root UI strings («asignación de plaza», «tolerancia admitida») and add a UI-copy freeze test — *provisional*

**Severidad:** blocker · **Esfuerzo:** S · **Lentes:** states, ipad, native-craft, visual

**Archivos:** `Dobacksoft Training/Features/Standing/StandingView.swift`, `Dobacksoft Training/Features/Resultados/ResultadosView.swift`, `Dobacksoft Training/Core/Models/AttemptDetailDTO.swift`, `Dobacksoft TrainingTests/DTOTests/ContractEnumFreezeTests.swift`

**Por qué importa:** «La asignación de plaza la decide CMadrid al cierre de la convocatoria.» renders under every candidate's position (StandingView HEAD:185, working tree :127) and in the results footnote (ResultadosView.swift:399) — the cupo sense of «plaza» that CMADRID-ENTREGA v1.1 denies and that the repo's own tests ban. `noPenaltyLabel` says «tolerancia admitida» (AttemptDetailDTO.swift:285), a literal hit on the forbidden root. Skeptics split blocker/important on the first; rule 4 of the audit makes it a blocker.

**Cambio propuesto:** Replace both sentences with: «El resultado de la oposición lo determina CMadrid al cierre formal de la convocatoria, fuera de esta aplicación.» (StandingView part is PROVISIONAL — coordinate with the other session; ResultadosView:399 is not). Change AttemptDetailDTO.swift:285 to «Dentro de la tolerancia permitida: no ha restado puntuación.». Do NOT touch «Plaza N» / «Nombre o plaza» (kiosk identifier, portal parity — refuted). Add `UICopyVocabularyTests` scanning the string literals the app owns (GradeFinality.note, NotFoundReason copy, AttemptEventDTO.noPenaltyLabel, SnapshotCopy, and a static list of footnote strings extracted into `Copy.swift`) for the roots apto|aprob|suspens|admitid|exclu|corte|withinCutoff|plazas|asignación de plaza.

**Test primero:** Dobacksoft TrainingTests/DTOTests/UICopyVocabularyTests.swift: `@Test func noPenaltyLabelsAvoidForbiddenRoots()` iterating every `AttemptEventDTO.noPenaltyLabel` variant (`dentro_de_tolerancia`, `franquicia`, default) and `#expect(!label.lowercased().contains("admitid"))`; a second test over a new `Copy.resultadoFueraDeLaApp` constant asserting it does not contain "plaza". Also extend StagingWalkthroughUITests banned list (:484) with "asignación de plaza".

#### 3. Keep the last good data on refresh: no blanking to a spinner, no error replacing loaded content — *provisional*

**Severidad:** important · **Esfuerzo:** M · **Lentes:** states, native-craft

**Archivos:** `Dobacksoft Training/Features/Standing/StandingView.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`, `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`

**Por qué importa:** Every ViewModel sets `state = .loading` first and `.error` on failure (StandingViewModel HEAD:23,34; MyAttemptsViewModel HEAD:707; ConvocatoriasListView.swift:16; AttemptDetailView.swift:16), so a pull-to-refresh on a weak signal wipes the position card the candidate was reading and replaces it with «No se ha podido conectar». The widget already keeps the last good value (SnapshotPublisher.swift:66-68); the app does not.

**Cambio propuesto:** In each ViewModel: `if case .loaded = state { isRefreshing = true } else { state = .loading }`; on failure while `.loaded`, keep the data and set `refreshError: String?` (rendered by the view as a dismissible capsule: «No se ha podido actualizar. Se muestra el último dato consultado.» with a «Reintentar» button); set `lastUpdated: Date` on success and show «Actualizado a las HH:mm» under the card. Inject `api: TrainingAPI` into StandingViewModel/MyAttemptsViewModel/ConvocatoriasViewModel/AttemptDetailViewModel to make this testable. StandingView parts PROVISIONAL.

**Test primero:** Dobacksoft TrainingTests/Features/StandingViewModelTests.swift: FakeTrainingAPI `standingResults = [.success(standing), .failure(APIError.transport(URLError(.notConnectedToInternet)))]`; `await vm.load(...)` twice; `#expect(vm.state == .loaded(standing))` and `#expect(vm.refreshError == "No se ha podido conectar. Compruebe su conexión a la red.")`. Same shape for ConvocatoriasViewModel (needs `convocatoriasResults`/`myConvocatoriasResults` in the fake).

#### 4. Embedded standing/attempts error cards get a heading, an icon and a per-section «Reintentar» — *provisional*

**Severidad:** important · **Esfuerzo:** S · **Lentes:** states, accessibility

**Archivos:** `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** In the main tab the position error is a red label with no button (HEAD:541-551) and the attempts error is a bare red sentence (HEAD:638-643); recovery depends on discovering pull-to-refresh, which in the embedded host is inert because the child's `.refreshable` is not the scroll owner and `.task(id:)` does not re-run. VoiceOver/Switch Control users have no path at all.

**Cambio propuesto:** PROVISIONAL. Replace both branches with `ContentUnavailableView { Label("No se ha podido cargar su posición", systemImage: "exclamationmark.triangle.fill") } description: { Text(msg) } actions: { Button("Reintentar") { Task { await standingVM.load(...) } } }` (and «No se han podido cargar sus intentos» → `attemptsVM.load(...)`), inside `.cardStyle()`, with `.accessibilityElement(children: .combine)`; add identifiers `standing.retry` and `attempts.retry`.

**Test primero:** Dobacksoft TrainingUITests/StagingWalkthroughUITests.swift: new `testStandingErrorOffersRetry()` launched with a launch argument that points BASE_URL at an unroutable host; after login-restore, `#expect(element("standing.retry", in: app).waitForExistence(timeout: 20))`. Complement with a unit test that `MyConvocatoriaContentView.retryStanding()` calls only `standingVM.load` (FakeTrainingAPI records one `standing` call and zero `myAttempts` calls).

#### 5. Empty states («Sin convocatorias», «Todavía no está inscrito») are refreshable and offer «Actualizar» — *provisional*

**Severidad:** important · **Esfuerzo:** S · **Lentes:** native-craft

**Archivos:** `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** `.refreshable` only works inside a scroll container; the empty branches are plain VStacks/ContentUnavailableViews (ConvocatoriasListView.swift:44-48; StandingView HEAD:320-332) with no action. A candidate enrolled after first launch stays on «Sin convocatorias» with no working control.

**Cambio propuesto:** Wrap the `.empty` (and `.error`) branches in `ScrollView { … .containerRelativeFrame(.vertical) }` so the pull gesture works everywhere, and add `actions: { Button("Actualizar") { Task { await load() } } }` with identifier `convocatorias.refresh` / `standing.refresh`. StandingView part PROVISIONAL.

**Test primero:** Unit: `ConvocatoriasViewModelTests.emptyThenPopulatedAfterReload()` — FakeTrainingAPI `myConvocatoriasResults = [.success([]), .success([conv])]`, load twice, `#expect(vm.state == .loaded([conv]))`. UI: in StagingWalkthroughUITests assert `element("convocatorias.refresh")` exists when the seeded empty account is used (skip if staging has no such account, as the file already does with XCTSkip).

#### 6. Offline or slow launch: tell the candidate their session is intact instead of dropping them on the login form

**Severidad:** important · **Esfuerzo:** M · **Lentes:** states

**Archivos:** `Dobacksoft Training/Core/Auth/AuthSession.swift`, `Dobacksoft Training/ContentView.swift`, `Dobacksoft Training/Features/Login/LoginView.swift`

**Por qué importa:** On a transport failure during restore, tokens survive but `user` stays nil, so RootView shows LoginView with no message after up to 15 s of «Restaurando sesión…» (AuthSession.swift:24,55-61; ContentView.swift:8-14). Typing credentials also fails, which reads as «my account is broken».

**Cambio propuesto:** Add `var restoreFailure: APIError?` to AuthSession, set in the transport catch, cleared on success/login. In RootView, when `restoreFailure != nil && refreshToken != nil` show a non-blaming state over LoginView: banner «Sin conexión. Su sesión sigue activa y se restaurará al recuperar la red.» with a «Reintentar» button that calls `restoreFromKeychain()` again. In LaunchView, after 5 s show «Está tardando más de lo habitual…». Defer caching UserDTO (option a) — not needed for this.

**Test primero:** Dobacksoft TrainingTests/Services/AuthSessionTests.swift: `@Test func restoreTransportFailureExposesReasonAndKeepsTokens()` — FakeTrainingAPI `meResults = [.failure(APIError.transport(URLError(.notConnectedToInternet)))]`, seeded Keychain; after `restoreFromKeychain()` `#expect(session.restoreFailure != nil && session.refreshToken != nil && session.hasRestoredSession)`; then `meResults = [.success(user)]`, restore again, `#expect(session.restoreFailure == nil && session.isAuthenticated)`.

#### 7. Forced logout explains itself: «Su sesión ha caducado por seguridad»

**Severidad:** important · **Esfuerzo:** S · **Lentes:** states

**Archivos:** `Dobacksoft Training/Core/Auth/AuthSession.swift`, `Dobacksoft Training/Features/Login/LoginView.swift`

**Por qué importa:** When the refresh token is rejected, `logout()` swaps to LoginView before any screen can render «La sesión ha caducado…» (AuthSession.swift:128-141; APIError.swift:27); LoginView's `errorMessage` is local and nil. The candidate is mid-scroll and lands on a blank login form.

**Cambio propuesto:** Add `enum LogoutReason { case sessionExpired, userInitiated }` and `var logoutReason: LogoutReason?` on AuthSession; set `.sessionExpired` in the two forced paths and the cold-start 401 path, `.userInitiated` in the Profile button. LoginView renders `auth.logoutReason == .sessionExpired` as an informational (non-red, `Color.brandTint`) banner «Su sesión ha caducado por seguridad. Inicie sesión de nuevo.» with identifier `login.sessionExpired`; clear it on successful login.

**Test primero:** AuthSessionTests: `@Test func rejectedRefreshRecordsSessionExpiredReason()` — `refreshResult = .failure(APIError.unauthenticated)`, call `authorized { _ in throw APIError.unauthenticated }`, `#expect(session.logoutReason == .sessionExpired && session.user == nil)`; `@Test func explicitLogoutRecordsUserInitiated()`.

#### 8. Login form: focus chain, submit-on-return, and VoiceOver announcement of the error

**Severidad:** important · **Esfuerzo:** S · **Lentes:** accessibility, ipad, native-craft

**Archivos:** `Dobacksoft Training/Features/Login/LoginView.swift`

**Por qué importa:** No `.focused/.submitLabel/.onSubmit` anywhere (repo-wide), so Return does nothing on either field and hardware-keyboard users must tap the button; the error text appears silently for VoiceOver (LoginView.swift:29-57, 87-98). This is the first screen every candidate sees.

**Cambio propuesto:** Add `enum Field { case email, password }` + `@FocusState private var focus: Field?`; email: `.focused($focus, equals: .email).submitLabel(.next).onSubmit { focus = .password }`; password: `.focused($focus, equals: .password).submitLabel(.go).onSubmit { if canSubmit { Task { await login() } } }`; button `.keyboardShortcut(.defaultAction)`; `.onAppear { focus = .email }`. After setting `errorMessage`, `AccessibilityNotification.Announcement(errorMessage).post()` and move `@AccessibilityFocusState` to the error Text. Keep `login.error` identifier on the error text.

**Test primero:** Dobacksoft TrainingUITests: `testLoginSubmitsFromKeyboard()` — type email, `app.keyboards.buttons["Siguiente"].tap()`, `#expect(app.secureTextFields["login.password"].hasKeyboardFocus)` (via `value(forKey:)`), type a wrong password, tap «Ir», `#expect(element("login.error", in: app).waitForExistence(timeout: 15))`. Unit: extract `canSubmit(email:password:isLoading:)` as a pure function and pin it in `LoginFormRulesTests`.

#### 9. Login layout: cap the form at 420 pt and make it scroll so the button survives landscape/keyboard/large text

**Severidad:** important · **Esfuerzo:** S · **Lentes:** ipad

**Archivos:** `Dobacksoft Training/Features/Login/LoginView.swift`

**Por qué importa:** On iPad the fields and button span ~960 pt (LoginView.swift:28-75, no maxWidth); on iPhone landscape or at accessibility text sizes the non-scrolling VStack (:10-84) overflows and pushes «Iniciar sesión» and the error off screen — layout arithmetic, not runtime-verified.

**Cambio propuesto:** Wrap the body in `ScrollView { GeometryReader-free content }.scrollDismissesKeyboard(.interactively)` using the `frame(minHeight: proxy.size.height)` pattern from ResultadosView.swift:160-184 so it centres when it fits; wrap the form VStack in `.frame(maxWidth: 420).frame(maxWidth: .infinity)`; hide the 56 pt shield when `verticalSizeClass == .compact`.

**Test primero:** Dobacksoft TrainingUITests: `testLoginSubmitVisibleInLandscapeWithKeyboard()` — `XCUIDevice.shared.orientation = .landscapeLeft`, tap `login.password`, `#expect(element("login.submit", in: app).isHittable)`; run also on the iPad destination the walkthrough already uses.

#### 10. Add an OnBrand colorset so primary buttons and selected chips keep ≥4.5:1 contrast in dark mode — *provisional*

**Severidad:** important · **Esfuerzo:** S · **Lentes:** accessibility, visual

**Archivos:** `Dobacksoft Training/Assets.xcassets/Colors/OnBrand.colorset/Contents.json`, `Dobacksoft Training/Shared/Theme/Theme+Modifiers.swift`, `Dobacksoft Training/Features/Login/LoginView.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`, `Dobacksoft Training/Features/Manager/ManagerPanelView.swift`

**Por qué importa:** `BrandPrimaryButtonStyle` hard-codes `.white` on `Color.brand`, whose dark value is #7C9CFF: 2.61:1, failing AA even for large text (Theme+Modifiers.swift:88-97; Brand.colorset). «Iniciar sesión», every «Reintentar», and the selected convocatoria chip are affected.

**Cambio propuesto:** Create `OnBrand` colorset (any: #FFFFFF, dark: #0B1A4A → 6.39:1 on #7C9CFF). Use `Color.onBrand` in BrandPrimaryButtonStyle, `ProgressView().tint(Color.onBrand)` at LoginView.swift:65 and ManagerPanelView.swift:423, and the chip foreground at StandingView HEAD:426 (that line PROVISIONAL). Do not use the #5B7CE6 alternative (3.84:1).

**Test primero:** Dobacksoft TrainingTests/Theme/BrandContrastTests.swift: parse `Brand.colorset` and `OnBrand.colorset` Contents.json from the test bundle (add them as test resources or read via `Bundle.main`), compute WCAG ratio for light and dark, `#expect(ratio >= 4.5)` for both appearances. This test fails today because OnBrand does not exist.

#### 11. «Mi posición» names the convocatoria and its closing date; «activas» count filtered or dropped — *provisional*

**Severidad:** important · **Esfuerzo:** S · **Lentes:** visual, states

**Archivos:** `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** With one convocatoria (the common case) the screen never shows its name or closing date — the two facts the web hero always prints — and the greeting counts CLOSED/LOCKED enrolments as «activas» (HEAD:351-354, 439-444; web dashboard.html:14-17).

**Cambio propuesto:** PROVISIONAL. Replace `subtitleForCount` with `selectedConvocatoria?.name` + optional « · Cierre \(APIDate.shortDate(closedAt))»; keep chips only when count > 1. If a count is kept, use `convocatorias.filter(ConvocatoriaScope.activas.matches).count`. Extract the subtitle builder into a pure `StandingHeaderCopy.subtitle(selected:closedAt:)`.

**Test primero:** Dobacksoft TrainingTests/Features/StandingHeaderCopyTests.swift: `#expect(StandingHeaderCopy.subtitle(name: "Oposición 2026", closedAt: "2026-10-12T00:00:00Z") == "Oposición 2026 · Cierre 12/10/2026")`, and `activeCount([open, locked]) == 1` using `ConvocatoriaScope.activas`.

#### 12. Align the provisional-results legal notice with the portal and show it on the attempt detail — *provisional*

**Severidad:** important · **Esfuerzo:** S · **Lentes:** visual

**Archivos:** `Dobacksoft Training/Core/Models/GradeFinality.swift`, `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** The web says «Resultados provisionales. No tienen efecto jurídico hasta el cierre oficial de la convocatoria» on every page including the attempt; iOS says only «esta nota puede variar» (GradeFinality.swift:68) and the attempt screen — the one most likely screenshotted — says nothing.

**Cambio propuesto:** Change `.provisional` note to «Resultado provisional. No tiene efecto jurídico hasta el cierre oficial de la convocatoria.» with an overload `note(closedAt:)` appending « (dd/MM/yyyy)» when known; add a `.definitive` note «Resultado definitivo al cierre de la convocatoria.». Thread `finality: GradeFinality` into `AttemptDetailView`/`AttemptDetailContent` (as `convocatoriaName` already is; manager callers default `.unknown`) and render `finality.note` as a `metaCaption` footer. StandingView caller PROVISIONAL.

**Test primero:** Dobacksoft TrainingTests/DTOTests/GradeFinalityTests.swift: `@Test func provisionalNoteStatesNoLegalEffect()` `#expect(GradeFinality.provisional.note?.contains("efecto jurídico") == true)`; `@Test func provisionalNoteAppendsClosingDate()`; keep the existing banned-vocabulary assertion (:60) green.

#### 13. Missing score is stated, not implied: «Sin nota» in the row and «Nota no disponible» hero in the detail — *provisional*

**Severidad:** important · **Esfuerzo:** S · **Lentes:** states

**Archivos:** `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** A scoreless attempt (a legitimate backend state; the app even has a «Sin nota» filter) opens on a card with no hero and no explanation (AttemptDetailView.swift:147-161), and the list row shows «—» (HEAD:769-773), which SnapshotCopy's own rule forbids («nunca un guion en lugar de una cifra»).

**Cambio propuesto:** Detail: `else` branch rendering `Text(SnapshotCopy.notaNoDisponible)` in the hero slot plus `Text("Este intento no tiene nota registrada.")` in `Color.muted`; move the quality badge outside the `if let s`. Row (PROVISIONAL): replace `Text("—")` with `Text("Sin nota").font(.metaCaption)` and fold it into the row's accessibility label.

**Test primero:** Dobacksoft TrainingTests/DTOTests/AttemptDetailDTOTests.swift: fixture variant with `"score": null` decodes and a new pure `AttemptScorePresentation(score:quality:)` returns `.unavailable(quality: .high)`; `#expect(presentation.heroText == "Nota no disponible.")`. AttemptSummaryDTOTests: `rowScoreText(nil) == "Sin nota"`.

#### 14. Attempt detail shows the attempt date (threaded from the list, no API change) — *provisional*

**Severidad:** important · **Esfuerzo:** S · **Lentes:** visual

**Archivos:** `Dobacksoft Training/Features/Standing/StandingView.swift`, `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`, `Dobacksoft Training/Features/Resultados/ResultadosView.swift`

**Por qué importa:** The detail has no date (AttemptDetailDTO has none; summary rows are Alumno/Recorrido/Tipo/Convocatoria) so several attempts on the same route are indistinguishable once opened, and the share text omits it too. `AttemptSummaryDTO.createdAt` is already in hand at every STUDENT call site.

**Cambio propuesto:** Extend `StudentAttemptRoute` with `createdAt: String?` (PROVISIONAL, StandingView) and `AttemptDetailView(attemptId:convocatoriaName:createdAt:)`; render `summaryRow(label: "Fecha", value: APIDate.shortDateTime(createdAt))` first when present and prepend «Fecha: …» to `shareText`. Manager entry points pass nil.

**Test primero:** Dobacksoft TrainingTests/Features/AttemptShareTextTests.swift: extract `AttemptShareText.build(attempt:convocatoriaName:createdAt:)` and `#expect(text.contains("Fecha: 06/09/2026 09:15"))` for a fixed ISO input; `#expect(!text.contains("Fecha"))` when nil.

#### 15. Show the grading gravity of each event (Leve / Moderada / Grave) as a badge

**Severidad:** important · **Esfuerzo:** S · **Lentes:** visual

**Archivos:** `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`, `Dobacksoft Training/Core/Models/AttemptDetailDTO.swift`

**Por qué importa:** `AttemptEventDTO.categoria` is decoded but never rendered (AttemptDetailDTO.swift:204; events card :334-382 shows only sensor intensity, which the backend documents as not the grading weight). The web shows the gravity tag on every event; it is the datum a candidate needs to understand or contest a grade.

**Cambio propuesto:** Add `var gravityLabel: (text: String, kind: BadgeKind)?` on AttemptEventDTO mapping GRAVE→(«Grave», .danger), MODERADA→(«Moderada», .warning), LEVE→(«Leve», .neutral), unknown non-nil→(raw, .neutral), nil→nil; render `StatusBadge` in the event header when non-nil. No threshold colouring beyond the per-event tag.

**Test primero:** Dobacksoft TrainingTests/DTOTests/EventPenaltyTests.swift: `@Test func gravityLabelsAreCastilian()` for the three values and `nil` → nil; also fix Fixtures/attempt-detail.json:66,79 to use LEVE/MODERADA/GRAVE (currently ESTABILIDAD/FIRME, which the backend never emits).

#### 16. Per-route progress grid («Sus recorridos») with best grade, «Pendiente» and an «Actual» badge on the counting attempt — *provisional*

**Severidad:** important · **Esfuerzo:** M · **Lentes:** visual

**Archivos:** `Dobacksoft Training/Features/Standing/StandingView.swift`, `Dobacksoft Training/Core/Models/RouteProgress.swift`

**Por qué importa:** The grade is «best attempt per required route» and the app says so in text, but the attempts are a flat date-sorted list (HEAD:612-626); the web dashboard's primary content is one card per route. Inputs (`StandingDTO.requiredRoutes`, `AttemptSummaryDTO.route.id/score/createdAt/isPractice`) are already decoded.

**Cambio propuesto:** PROVISIONAL. New pure `RouteProgress.derive(requiredRoutes:attempts:)` → `[RouteProgress]` (code, best non-practice attempt or nil, treating nil score as 0 like `_reduce_best_by_route`). Render a 2-column `LazyVGrid` of cards above «Mis intentos» only when `composition?.isGlobalBest == false`; pending cards show the route code + `StatusBadge("Pendiente", .neutral)`; add `StatusBadge("Actual", .brand)` in `AttemptSummaryRow` for ids in `RouteProgress.countingAttemptIds`. Drop the stale comment at HEAD:568-573. Optional follow-on (V-15): «Último intento» metric and «Mejor recorrido / A mejorar» line from the same derivation.

**Test primero:** Dobacksoft TrainingTests/DTOTests/RouteProgressTests.swift: required ["1A","2B"], attempts {1A: 6.0 practice, 1A: 5.5, 1A: nil} → 1A best = 5.5 attempt id, 2B pending; `#expect(progress.countingAttemptIds == [id55])`; practice excluded; nil score counts as 0 but still marks the route as driven.

#### 17. One spoken and visible scale for grades: «8,5 sobre 10» for VoiceOver, «/10» caption on the standing score, one hero element — *provisional*

**Severidad:** important · **Esfuerzo:** S · **Lentes:** accessibility, visual

**Archivos:** `Dobacksoft Training/Shared/ScoreFormat.swift`, `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** The attempt hero is three unrelated VoiceOver stops («8,5», «barra diez», «Calidad alta») with no noun (AttemptDetailView.swift:146-158); StandingMetric announces «Nota provisional: 4,75» with no scale and the card shows none visually either, while the web says «sobre 10 puntos». The position VStack is read in three fragments (HEAD:137-147).

**Cambio propuesto:** Add `ScoreFormat.spoken(_ value: Double, decimals:) -> String` («4,75 sobre 10»). Hero: `.accessibilityElement(children: .ignore).accessibilityLabel("Nota del intento: \(spoken)" + quality)`. StandingMetric (PROVISIONAL): add `spokenValue:` parameter and a `Text("sobre 10")` metaCaption under the grade; group the position VStack with `.ignore` + «Puesto N de M aspirantes»; apply spoken form to the «Media de lo conducido» row and AttemptSummaryRow.

**Test primero:** Dobacksoft TrainingTests/DTOTests/ScoreFormatTests.swift: `@Test func spokenAggregateUsesCommaAndScale()` `#expect(ScoreFormat.spoken(4.75, decimals: 2) == "4,75 sobre 10")`, `#expect(ScoreFormat.spoken(8.5, decimals: 1) == "8,5 sobre 10")` — fails until the helper exists.

#### 18. Translate the role: «Aspirante» / «Instructor» / «Administración» instead of STUDENT/Student; hide the organisation UUID

**Severidad:** important · **Esfuerzo:** S · **Lentes:** accessibility, visual

**Archivos:** `Dobacksoft Training/Core/Models/StatusVocabulary.swift`, `Dobacksoft Training/Features/Dashboard/DashboardView.swift`, `Dobacksoft Training/Features/Manager/ManagerPanelView.swift`, `Dobacksoft Training/Features/Manager/StudentProfileView.swift`

**Por qué importa:** The profile badge and «Rol» row show the raw English enum (DashboardView.swift:186,276) and «Organización» shows a database id (:187-189) in an otherwise formal Castilian UI; the portal says «Aspirante» (layout.html:101).

**Cambio propuesto:** Add `StatusVocabulary.role(_ raw: String?) -> String` (STUDENT→«Aspirante», MANAGER→«Instructor», ADMIN/SUPER_ADMIN→«Administración», unknown→raw); use it at the four call sites. Remove the organisation-id row (or move under the technical «API» section as «Ref. organización»). Org *name* needs backend — see needsBackend.

**Test primero:** Dobacksoft TrainingTests/DTOTests/StatusVocabularyTests.swift: `@Test func roleLabelsAreCastilian()` for the four known values and `#expect(StatusVocabulary.role("OBSERVER") == "OBSERVER")`; add role labels to the existing banned-vocabulary loop (:78).

#### 19. «Filtros» menu and «Restablecer filtros»: 44 pt targets and announced active state — *provisional*

**Severidad:** important · **Esfuerzo:** S · **Lentes:** accessibility

**Archivos:** `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** Both are 12 pt captions with ~15 pt hit height and no `accessibilityValue` (HEAD:669-677, 600-606); when a filter empties the list VoiceOver hears «Filtros de intentos, botón» with no hint that a filter is active, so the empty list looks like missing data.

**Cambio propuesto:** PROVISIONAL. `.frame(minHeight: 44).contentShape(Rectangle())` on both labels (or `.buttonStyle(.bordered).controlSize(.small)`); `.accessibilityValue("\(sortMode.title), \(qualityFilter.title), \(scoreFilter.title)")` on the Menu; identifiers `attempts.filters` and `attempts.resetFilters`.

**Test primero:** Dobacksoft TrainingTests/Features/AttemptFiltersTests.swift: extract `AttemptFilters.accessibilitySummary(sort:quality:score:)` and `#expect(summary == "Más recientes, Todas las calidades, Todas las notas")` for defaults; UI: `#expect(element("attempts.filters", in: app).frame.height >= 44)`.

#### 20. Refresh on return to foreground and show «Actualizado a las HH:mm» on data screens — *provisional*

**Severidad:** important · **Esfuerzo:** M · **Lentes:** native-craft

**Archivos:** `Dobacksoft Training/ContentView.swift`, `Dobacksoft Training/Shared/RefreshTicker.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** Nothing observes `scenePhase` (repo-wide); data loads once via `.task` and the candidate returning the next morning sees yesterday's position with no timestamp, while the widget refuses to show a 6 h-old figure unlabelled (SnapshotFreshness.swift:5-7).

**Cambio propuesto:** `@Observable final class RefreshTicker { var generation = 0; var lastBackgrounded: Date? }` injected in RootView; on `.active` after ≥5 min in background bump `generation`; screens use `.task(id: ticker.generation)`. Reuse `lastUpdated` from item 3 to caption the card. StandingView part PROVISIONAL.

**Test primero:** Dobacksoft TrainingTests/Services/RefreshTickerTests.swift: `ticker.scenePhaseChanged(to: .background, at: t0)` then `.active` at `t0 + 60` → generation unchanged; at `t0 + 600` → generation + 1. Fixed dates as in SnapshotTests.

#### 21. Dashboard router: one shared section + NavigationPath per section for TabView and sidebar

**Severidad:** important · **Esfuerzo:** M · **Lentes:** ipad

**Archivos:** `Dobacksoft Training/Features/Dashboard/DashboardView.swift`, `Dobacksoft Training/Features/Dashboard/DashboardRouter.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`

**Por qué importa:** `if sizeClass == .regular` swaps two unrelated trees (DashboardView.swift:12-19), so a Split View drag or an iPhone Pro Max rotation discards every pushed screen and view model; the single detail NavigationStack has no path binding, so switching sidebar sections while drilled in leaves a stale push stack (:89-93) — contradicting the code's own comment at :62-64.

**Cambio propuesto:** `@Observable final class DashboardRouter { var section: SidebarSection; var paths: [SidebarSection: NavigationPath] }` created once in DashboardView, `@SceneStorage("dashboard.section")` for the raw value. Bind `TabView(selection: $router.section)` and `List(selection:)` to it; detail becomes `switch section { case .convocatorias: NavigationStack(path: $router.paths[.convocatorias]) { ConvocatoriasListView() } … }`. Hoist `.navigationDestination(for: ConvocatoriaSummaryDTO.self)` out of `loadedList` to the section root. Stop-gap if deferred: `.id(selection)` on the stack.

**Test primero:** Dobacksoft TrainingTests/Features/DashboardRouterTests.swift: `router.push(.convocatorias, conv)`; `router.section = .perfil`; `#expect(router.paths[.convocatorias]?.count == 1)`; `#expect(router.paths[.perfil]?.isEmpty == true)`. UI (iPad destination): extend the skipped iPad walkthrough (StagingWalkthroughUITests.swift:71-86) to tap `sidebar.convocatorias`, open a row, tap `sidebar.perfil`, `#expect(app.navigationBars["Perfil"].exists)`.

#### 22. Widget deep-links to «Mi posición»; «caducado» copy names the screen that refreshes it

**Severidad:** important · **Esfuerzo:** M · **Lentes:** states, native-craft, ipad

**Archivos:** `Dobacksoft Training/Info.plist`, `Dobacksoft Training Widgets/Dobacksoft_Training_Widgets.swift`, `Dobacksoft Training/ContentView.swift`, `Dobacksoft Training/Features/Dashboard/DashboardView.swift`, `SharedSnapshot/SnapshotCopy.swift`

**Por qué importa:** The widget tells the candidate to open «Mi posición», but tapping it opens Convocatorias (no `widgetURL`/`onOpenURL`/URL scheme anywhere), and `caducado` says «Abra la aplicación» although only the standing screen republishes the snapshot (SnapshotCopy.swift:38-39,52; DashboardView.swift:197-199).

**Cambio propuesto:** Depends on item 21. Add `CFBundleURLTypes` scheme `dobacksoft-training`; `.widgetURL(URL(string: "dobacksoft-training://mi-posicion"))` on StandingWidgetEntryView; `.onOpenURL` in RootView → `router.section = .miPosicion` when `auth.isAuthenticated && user.isStudent`. Change `SnapshotCopy.caducado` to «Sin datos recientes. Abra «Mi posición» en la aplicación para actualizarlos.». URL parsing lives in the app, never in SharedSnapshot.

**Test primero:** Dobacksoft TrainingTests/Snapshot/SnapshotTests.swift: `@Test func expiredCopyNamesMiPosicion()` `#expect(SnapshotCopy.caducado.contains("«Mi posición»"))`. Dobacksoft TrainingTests/Services/DeepLinkTests.swift: `DeepLink(url: URL(string: "dobacksoft-training://mi-posicion")!) == .miPosicion`, unknown host → nil.

#### 23. Readable-width cap (680 pt) for every ScrollView content column on iPad — *provisional*

**Severidad:** important · **Esfuerzo:** M · **Lentes:** ipad

**Archivos:** `Dobacksoft Training/Shared/Theme/Theme+Modifiers.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriaDetailView.swift`, `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`, `Dobacksoft Training/Features/Manager/ManagerPanelView.swift`, `Dobacksoft Training/Features/Manager/StudentProfileView.swift`, `Dobacksoft Training/Features/Manager/WebfletAlertsView.swift`

**Por qué importa:** No finite `maxWidth` exists anywhere in the app; cards, metric pairs and footnotes stretch to 700-800 pt in the iPad detail pane — the stretched-phone look the owner ruled out.

**Cambio propuesto:** Add `func readableWidth(_ max: CGFloat = 680) -> some View { frame(maxWidth: max).frame(maxWidth: .infinity) }` and apply to each ScrollView's content VStack (one line per screen). In regular width, lay StandingCard and the attempts list side by side with `ViewThatFits`. StandingView/ConvocatoriaDetailView parts PROVISIONAL.

**Test primero:** Dobacksoft TrainingUITests on the iPad destination: after login, `let card = element("standing.card", in: app)` (add the identifier) and `#expect(card.frame.width <= 700)` in landscape.

#### 24. Widget: text styles instead of fixed 34/22/9 pt, and freshness note in the VoiceOver label

**Severidad:** important · **Esfuerzo:** S · **Lentes:** accessibility

**Archivos:** `Dobacksoft Training Widgets/Dobacksoft_Training_Widgets.swift`

**Por qué importa:** `.system(size:)` ignores Dynamic Type; the «Consultado el …» line — the only signal the figure may be 6-48 h old — is 9 pt (lines 195, 232, 245, 281-284) and is absent from `accessibilityText` (:292-307), so VoiceOver users get no freshness information at all.

**Cambio propuesto:** Position `.largeTitle.weight(.bold)` (small) / `.title.weight(.bold)`, score `.title2.weight(.semibold)`, age note and «de N» `.caption2` with `.minimumScaleFactor(0.8)`, `.fontDesign(.rounded)` if wanted; append `SnapshotCopy.consultadoEl(capturedAt)` to `accessibilityText` when `freshness == .envejecido`.

**Test primero:** Dobacksoft TrainingTests/Snapshot/SnapshotTests.swift (or a widget-target test if one is added): extract `StandingWidgetCopy.accessibilityText(state:capturedAt:)` into SharedSnapshot and `#expect(text.contains("Consultado el"))` for an aged snapshot at fixed t0.

#### 25. Widget palette follows dark mode: colorsets in the widget catalog instead of light-only hex literals

**Severidad:** important · **Esfuerzo:** S · **Lentes:** native-craft, accessibility, visual

**Archivos:** `Dobacksoft Training Widgets/SharedAssets.swift`, `Dobacksoft Training Widgets/Assets.xcassets`

**Por qué importa:** Seven `Color(red:green:blue:)` literals (SharedAssets.swift:11-17) drive `.containerBackground` and all text; on a dark home screen the widget is a cream card that does not follow the appearance the app itself honours.

**Cambio propuesto:** Add Paper/PaperElevated/Ink/Muted/Brand/BrandTint/Success/Danger colorsets to `Dobacksoft Training Widgets/Assets.xcassets` copying the app's light/dark components; point `Color.widget*` at `Color("Paper", bundle: .main)` etc. so call sites do not change; fill or delete the empty `WidgetBackground` colorset.

**Test primero:** Dobacksoft TrainingTests/Theme/WidgetPaletteTests.swift: read each widget colorset JSON from the repo (test resource) and `#expect(colors.contains { $0.appearances?.contains { $0.value == "dark" } == true })` for every token — fails today because the colorsets do not exist.

#### 26. Animate state changes with the existing Theme.motion tokens — *provisional*

**Severidad:** important · **Esfuerzo:** M · **Lentes:** native-craft

**Archivos:** `Dobacksoft Training/Features/Standing/StandingView.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`, `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`

**Por qué importa:** `Theme.motion` is used exactly once (button press); loading→loaded→error are hard cuts, the hero number jumps, re-sorting the attempts list snaps, chip selection recolours instantly (HEAD:66-98,141-143,594-631). It works, but it reads as a page reload.

**Cambio propuesto:** PROVISIONAL. Make ViewModel `State` enums Equatable (DTOs are Hashable already); `.animation(Theme.motion.base, value: viewModel.state)` on each switching Group with `.transition(.opacity)`; `.contentTransition(.numericText())` on position/score Texts; `withAnimation(Theme.motion.outStrong) { selectedId = conv.id }`; `.animation(Theme.motion.base, value: sortMode)` on the attempts ForEach.

**Test primero:** Dobacksoft TrainingTests/Features/StandingViewModelTests.swift: `#expect(StandingViewModel.State.loaded(standing) == .loaded(standing))` and `.error("a") != .error("b")` — compile-time proof of Equatable, which the animation modifiers require.

#### 27. Last-known data store with data age for convocatorias, standing and attempts — *provisional*

**Severidad:** important · **Esfuerzo:** L · **Lentes:** states

**Archivos:** `Dobacksoft Training/Shared/LastGoodStore.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`, `Dobacksoft Training/Core/Auth/AuthSession.swift`

**Por qué importa:** Every screen is network-or-nothing (no URLCache, no persistence outside the widget snapshot); a candidate in a garage has nothing to read and when data loads nothing says how old it is. Item 3 fixes the in-session case; this covers cold start offline.

**Cambio propuesto:** Per-user JSON files in the app container (`capturedAt` + DTO) written on every successful load, read on `.transport` failure and rendered with a header «Datos de la última consulta · » + `SnapshotCopy.consultadoEl` and `SnapshotFreshness` thresholds; cleared in `logout()` alongside `SnapshotPublisher.clear()`. Do it after items 3 and 6. StandingView part PROVISIONAL.

**Test primero:** Dobacksoft TrainingTests/Services/LastGoodStoreTests.swift: round-trip `StandingDTO` fixture at fixed t0 into a temp directory, `#expect(store.read(StandingDTO.self, key:).capturedAt == t0)`; `clear(userId:)` removes only that user's files.

#### 28. Error copy that says what to do: fixed formal sentences for 5xx/422/decoding/unexpected and «No se ha podido cargar» titles — *provisional*

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** states

**Archivos:** `Dobacksoft Training/Core/API/APIError.swift`, `Dobacksoft Training/Core/API/APIClient.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`, `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** A nginx 502 yields the fragment «Error del servidor» under a title «Error»; `.unexpected` exposes the HTTP status; none says whether to wait or retry (APIError.swift:33-37; APIClient.swift:177-191).

**Cambio propuesto:** `.server` → «El servidor no está disponible en este momento. Inténtelo de nuevo en unos minutos; si el problema continúa, avise a su instructor.»; `.validation` → «No se ha podido procesar la petición. Inténtelo de nuevo.»; drop the status code from `.unexpected`; log status+body via `AppLog.api`. Retitle the ContentUnavailableViews «No se ha podido cargar». Update APIErrorTests:33-41 accordingly. StandingView titles PROVISIONAL.

**Test primero:** Dobacksoft TrainingTests/Services/APIErrorTests.swift: rewrite `serverErrorMessage`/`validationMessage` to expect the fixed sentences regardless of the backend `message`, and `unexpectedMessage` to `#expect(!msg.contains("418"))`.

#### 29. Cancelled requests are not «No se ha podido conectar»: rethrow cancellation and guard ViewModel state — *provisional*

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** states

**Archivos:** `Dobacksoft Training/Core/API/APIClient.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** `send` wraps `URLError.cancelled`/`CancellationError` as `.transport` (APIClient.swift:153-157) and the shared ViewModels write `.error` without checking `Task.isCancelled`, so switching convocatoria chips mid-load flashes a network error although the network is fine.

**Cambio propuesto:** In `APIClient.send`: `if (error as? URLError)?.code == .cancelled || error is CancellationError { throw error }` before wrapping. In each ViewModel catch: `guard !Task.isCancelled else { return }`. StandingView part PROVISIONAL.

**Test primero:** Dobacksoft TrainingTests/Features/StandingViewModelTests.swift: FakeTrainingAPI `standingResults = [.failure(CancellationError())]`; `await vm.load(...)`; `#expect(vm.state == .loading)` (not `.error`). Plus an APIClient-level test that `APIError.transport` is never constructed from `URLError(.cancelled)` if a `mapTransportError` helper is extracted.

#### 30. Convocatoria chips: 44 pt height, isSelected trait, animated selection, selected chip scrolled into view — *provisional*

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** accessibility, native-craft

**Archivos:** `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** Chips are ~32 pt with `accessibilityValue("seleccionada")` instead of the native trait and no animation or `scrollPosition` (HEAD:406-437); only affects candidates in 2+ convocatorias.

**Cambio propuesto:** PROVISIONAL. `.frame(minHeight: 44)`, `.accessibilityAddTraits(isSelected ? .isSelected : [])` (remove the value), `withAnimation(Theme.motion.outStrong)` on select, `.scrollTargetLayout()` + `.scrollPosition(id: $selectedId)`; wrap the HStack in `.accessibilityElement(children: .contain).accessibilityLabel("Convocatoria")`. In regular width consider a segmented `Picker` when count ≤ 3.

**Test primero:** UI: with a 2-convocatoria staging account (XCTSkip otherwise), `#expect(app.buttons[convName].isSelected)` after tap and `frame.height >= 44`.

#### 31. CardButtonStyle with press highlight and iPad pointer hover for every NavigationLink card/row — *provisional*

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** ipad

**Archivos:** `Dobacksoft Training/Shared/Theme/Theme+Modifiers.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`, `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriaDetailView.swift`

**Por qué importa:** All cards use `.buttonStyle(.plain)` and there is no `hoverEffect` anywhere; on iPad with a trackpad nothing lifts or highlights. Chevrons and hints already signal interactivity, so this is craft, not discoverability.

**Cambio propuesto:** `struct CardButtonStyle: ButtonStyle` overlaying `Color.brand.opacity(configuration.isPressed ? 0.08 : 0)` in the card radius + `.hoverEffect(.highlight)` (rows) / `.lift` (free cards); `.buttonStyle(.card)` at the listed sites (Standing/ConvocatoriaDetail PROVISIONAL). Manager sites optional.

**Test primero:** Dobacksoft TrainingTests/Theme/CardButtonStyleTests.swift: pure `CardButtonStyle.overlayOpacity(isPressed:)` returns 0.08/0 — thin, but pins the contract; the visual is checked in the iPad walkthrough screenshot.

#### 32. Haptics on login result and chip selection via .sensoryFeedback — *provisional*

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** native-craft

**Archivos:** `Dobacksoft Training/ContentView.swift`, `Dobacksoft Training/Features/Login/LoginView.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** No haptic API is used anywhere; login failure/success and the custom chip picker are silent (pull-to-refresh and the logout dialog already get system haptics).

**Cambio propuesto:** LoginView: `.sensoryFeedback(.error, trigger: errorMessage) { _, new in new != nil }`; RootView (not LoginView, which is removed on success): `.sensoryFeedback(.success, trigger: auth.isAuthenticated) { $1 }`; chips: `.sensoryFeedback(.selection, trigger: selectedId)` (PROVISIONAL).

**Test primero:** No unit seam for haptics; make the trigger conditions pure (`LoginFeedback.shouldSignalError(old:new:)`) and pin them in `LoginFormRulesTests` so the `condition:` closure never fires on reset-to-nil.

#### 33. Per-row progress bar in the score breakdown (web parity), guarded by max > 0

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** visual

**Archivos:** `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`

**Por qué importa:** «2,21 / 3,75» next to «0,90 / 1,00» needs mental arithmetic; the web draws a bar under each measured row (intento_detalle.html:479-483). Numbers on iOS are already correct and complete.

**Cambio propuesto:** Under each `.measured(obtained, max)` row when `max > 0`: `ProgressView(value: obtained, total: max).tint(Color.brand).accessibilityHidden(true)`; no percentage text, no colour threshold.

**Test primero:** Dobacksoft TrainingTests/DTOTests/ScoreBreakdownRowTests.swift: `@Test func barFractionIsClampedAndNilWhenMaxIsZero()` on a new `ScoreBreakdownRow.barFraction: Double?` — 2.21/3.75 → 0.589…, max 0 → nil, obtained > max → 1.0.

#### 34. Share sheets use UI labels, not enum codes, and carry a SharePreview — *provisional*

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** visual, native-craft

**Archivos:** `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriaDetailView.swift`

**Por qué importa:** `shareText` emits «Calidad: HIGH» (AttemptDetailView.swift:99) and «Estado: OPEN» (ConvocatoriaDetailView HEAD:35) — English codes never shown on screen — with a generic share header.

**Cambio propuesto:** Use `attempt.quality?.label` and `StatusVocabulary.convocatoria(s).label`; `ShareLink(item:, preview: SharePreview("Intento · \(route)", image: Image(systemName: "trophy.fill")))`. Reuse `AttemptShareText.build` from item 14. ConvocatoriaDetailView PROVISIONAL.

**Test primero:** Dobacksoft TrainingTests/Features/AttemptShareTextTests.swift: `#expect(text.contains("Calidad: Calidad alta") && !text.contains("HIGH"))`; `ConvocatoriaShareTextTests`: `!text.contains("OPEN")`.

#### 35. One noun for the person: «aspirante» (drop «candidatos» / «alumno» in STUDENT-facing copy) — *provisional*

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** visual

**Archivos:** `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriaDetailView.swift`, `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`, `Dobacksoft Training/Features/Manager/StudentProfileView.swift`

**Por qué importa:** «N candidatos» on the list, «aspirantes» one tap later, «Alumno» on the candidate's own attempt (ConvocatoriasListView.swift:183; AttemptDetailView.swift:182-189); the portal says «aspirante» throughout.

**Cambio propuesto:** Replace the metric label with «aspirantes», ConvocatoriaDetail «Candidatos» → «Aspirantes» (PROVISIONAL), AttemptDetail row «Alumno» → «Aspirante», StudentProfile copy accordingly.

**Test primero:** Extend `UICopyVocabularyTests` (item 2) with `#expect(!copy.contains("alumno") && !copy.contains("candidato"))` over the extracted student-facing labels.

#### 36. Show the route code next to its name in attempt rows and detail — *provisional*

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** visual

**Archivos:** `Dobacksoft Training/Core/Models/AttemptDetailDTO.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`, `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`

**Por qué importa:** `displayName` hides the code whenever a name exists (AttemptDetailDTO.swift:30); the code is what the kiosk and the exam sheet print, and the web shows both.

**Cambio propuesto:** Add `AttemptRouteDTO.codeIfDistinct: String?` (id when `name != nil && id != name`); render it as `metaCaption` in `Color.muted` beside the name in AttemptSummaryRow (PROVISIONAL) and the «Recorrido» row.

**Test primero:** Dobacksoft TrainingTests/DTOTests/AttemptDetailDTOTests.swift: `codeIfDistinct` is "2A1" for {id 2A1, name Circuito norte}, nil when only id, nil when id == name.

#### 37. Web KPIs from data already loaded: «Último intento», «Mejor recorrido · A mejorar» — *provisional*

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** visual

**Archivos:** `Dobacksoft Training/Features/Standing/StandingView.swift`, `Dobacksoft Training/Core/Models/RouteProgress.swift`

**Por qué importa:** StandingCard shows only grade and attempt count; the web adds last-attempt date and best/worst route from the same `myAttempts` data.

**Cambio propuesto:** PROVISIONAL; build on item 16's `RouteProgress`. Third StandingMetric «Último intento» = `APIDate.shortDate(max createdAt)`; muted line «Mejor recorrido: X (n,n) · A mejorar: Y (n,n)» only when X ≠ Y; neutral colour.

**Test primero:** RouteProgressTests: `bestAndWorst()` returns nil when a single route, distinct codes otherwise; `lastAttemptDate` picks the max ISO instant.

#### 38. Redacted skeletons instead of spinner + caption, with a slow-network hint after 4 s — *provisional*

**Severidad:** minor · **Esfuerzo:** M · **Lentes:** states, native-craft

**Archivos:** `Dobacksoft Training/Features/Standing/StandingView.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`, `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`

**Por qué importa:** Every screen flashes a centred spinner and the layout pops in at a different height (`redacted` unused anywhere); with a 15 s timeout nothing says the network is slow.

**Cambio propuesto:** Static `.placeholder` DTOs; render `StandingCard(.placeholder).redacted(reason: .placeholder)` and three `ConvocatoriaRow(.placeholder)` while loading; a `Task.sleep(4s)` toggles «Está tardando más de lo habitual…». Standing part PROVISIONAL.

**Test primero:** Dobacksoft TrainingTests/DTOTests/StandingDTOTests.swift: `StandingDTO.placeholder` has no forbidden vocabulary and `position > 0` (the existing banned-word loop at :94 covers it).

#### 39. Semantic numeric roles in Theme+Typography (metricValue / metricValueLarge / scoreHero) — *provisional*

**Severidad:** minor · **Esfuerzo:** M · **Lentes:** visual

**Archivos:** `Dobacksoft Training/Shared/Theme/Theme+Typography.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`, `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriaDetailView.swift`, `Dobacksoft Training/Features/Dashboard/DashboardView.swift`

**Por qué importa:** Grades appear as Inter 18, Inter 20 and Fraunces 56 across the student flow via six ad-hoc size calls; design-system hygiene, not a defect.

**Cambio propuesto:** Add `.metricValue` (Inter SemiBold 20 / .title3), `.metricValueLarge` (Fraunces Bold 28 / .title), `.scoreHero` (Fraunces Bold 56 / .largeTitle); migrate the student-flow sites (Standing/ConvocatoriaDetail PROVISIONAL). Manager sites optional.

**Test primero:** Dobacksoft TrainingTests/Theme/TypographyRolesTests.swift: the three roles exist and are distinct `Font` values (`#expect(Font.metricValue != Font.scoreHero)`).

#### 40. Redact content in the app switcher; optional Face ID lock toggle

**Severidad:** minor · **Esfuerzo:** M · **Lentes:** native-craft

**Archivos:** `Dobacksoft Training/ContentView.swift`, `Dobacksoft Training/Features/Dashboard/DashboardView.swift`, `Dobacksoft Training/Info.plist`

**Por qué importa:** The widget is privacy-first (off by default, `.privacySensitive()`), yet the app opens straight into position/score and the app-switcher thumbnail shows the standing card; no `scenePhase` handling exists. Enhancement, not a defect.

**Cambio propuesto:** (a) In RootView overlay `Color.paper` with the app mark when `scenePhase != .active` — trivial. (b) Opt-in toggle in Perfil «Proteger con Face ID o código» (UserDefaults), `LAContext().evaluatePolicy(.deviceOwnerAuthentication)` at cold start and after N minutes in background; add `NSFaceIDUsageDescription`.

**Test primero:** Dobacksoft TrainingTests/Services/PrivacyGateTests.swift: pure `PrivacyGate.shouldRequireAuth(enabled:lastActive:now:)` — false when disabled, true after ≥ 5 min, false at 60 s.

#### 41. Rate-limit countdown disables the login button until retryAfter elapses

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** states

**Archivos:** `Dobacksoft Training/Features/Login/LoginView.swift`

**Por qué importa:** «Inténtelo de nuevo en 60 s» is static and the button stays enabled, inviting a retry that fails (APIError.swift:30-32; LoginView.swift:71).

**Cambio propuesto:** On `.rateLimited(retryAfter:)` store `retryUntil: Date`; `.disabled` while `Date() < retryUntil`; render remaining seconds with `TimelineView(.periodic(from:by: 1))`.

**Test primero:** LoginFormRulesTests: `canSubmit(..., retryUntil: t0 + 30, now: t0) == false`, `now: t0 + 31 == true`.

#### 42. Perfil «Estado del servidor» row: short value, detail in footer, tappable to re-check

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** states

**Archivos:** `Dobacksoft Training/Features/Dashboard/DashboardView.swift`

**Por qué importa:** The row's value column fills with a full error sentence and `checkHealth()` runs once per appearance with no way to re-run (DashboardView.swift:216, 238, 305-309).

**Cambio propuesto:** Value «Disponible» / «No disponible» / «Comprobando…»; message in the section footer; make the row a Button calling `checkHealth()` with a spinner and identifier `profile.health`.

**Test primero:** Dobacksoft TrainingTests/Features/ServerHealthPresentationTests.swift: pure mapping from `Result<HealthDTO, APIError>` to `(value, footer)`; transport error → («No disponible», «No se ha podido conectar…»).

#### 43. Toolbar «Actualizar» (⌘R) on root screens and ⌘1-4 section shortcuts on iPad — *provisional*

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** ipad

**Archivos:** `Dobacksoft Training/Features/Dashboard/DashboardView.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** Reload depends on discovering pull-to-refresh; no keyboard shortcuts exist for iPad keyboards.

**Cambio propuesto:** `ToolbarItem(placement: .topBarTrailing) { Button("Actualizar", systemImage: "arrow.clockwise") { Task { await load() } }.keyboardShortcut("r", modifiers: .command) }` on Convocatorias/Mi posición/Panel; hidden buttons with `.keyboardShortcut("1"…"4")` setting `router.section` (after item 21). Standing part PROVISIONAL.

**Test primero:** UI: `#expect(app.buttons["Actualizar"].exists)` on the Convocatorias root in the walkthrough.

#### 44. Context menus on convocatoria and attempt rows (share, open «Mi posición») — *provisional*

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** native-craft

**Archivos:** `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** Long-press does nothing anywhere (`contextMenu` unused).

**Cambio propuesto:** `.contextMenu { ShareLink(item: shareText); Button("Mi posición", systemImage: "trophy.fill") { router.paths[.convocatorias].append(...) } }` on convocatoria rows; `.contextMenu { ShareLink(...) }` on attempt rows (PROVISIONAL). Reuse share builders from items 14/34.

**Test primero:** UI: `element("convocatorias.row").press(forDuration: 1)`; `#expect(app.buttons["Mi posición"].waitForExistence(timeout: 3))`.

#### 45. Anchor the logout confirmationDialog to the button so the iPad popover points at it

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** ipad

**Archivos:** `Dobacksoft Training/Features/Dashboard/DashboardView.swift`

**Por qué importa:** Attached to the whole Form (DashboardView.swift:240), the iPad popover appears mid-pane pointing at nothing.

**Cambio propuesto:** Move `.confirmationDialog(...)` onto the destructive Button inside the last Section.

**Test primero:** UI (iPad destination): tap «Cerrar sesión», `#expect(app.sheets.firstMatch.exists || app.popovers.firstMatch.exists)` and the popover frame intersects the button frame's vertical band.

#### 46. Launch and Login use Theme tokens (themed text field style, muted caption, scaled icon)

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** visual

**Archivos:** `Dobacksoft Training/ContentView.swift`, `Dobacksoft Training/Features/Login/LoginView.swift`, `Dobacksoft Training/Shared/Theme/Theme+Modifiers.swift`

**Por qué importa:** LaunchView uses `.footnote`/`.secondary`, Login uses `.roundedBorder` and a fixed 56 pt icon (ContentView.swift:27-29; LoginView.swift:16,30,40) — the first two screens are the least on-brand.

**Cambio propuesto:** `ThemedTextFieldStyle` (padding base, `Color.paperElevated` fill, `RoundedRectangle(Theme.radius.medium)` + `Color.rule` stroke); LaunchView `.font(.metaCaption)` + `Color.muted` + `.tint(Color.brand)`; icon `.font(.display(size: 56, weight: .bold, italic: false, relativeTo: .largeTitle))`.

**Test primero:** Dobacksoft TrainingUITestsLaunchTests already screenshots the launch screen; add an assertion that `login.email` exists with the same identifiers (guards the restyle from breaking the walkthrough).

#### 47. Convocatoria header card: explicit VoiceOver sentence and no lineLimit at accessibility sizes — *provisional*

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** accessibility

**Archivos:** `Dobacksoft Training/Features/Convocatorias/ConvocatoriaDetailView.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`

**Por qué importa:** `.combine` yields «Nombre, Abierta, 120, Candidatos, Cierre punto medio 12/10/2026…» (HEAD:56-70); names are `.lineLimit(3)`/(2).

**Cambio propuesto:** PROVISIONAL. `.accessibilityElement(children: .ignore)` + label «\(name), \(statusLabel), \(n) aspirantes, cierre el \(longDate), actualizado el \(longDateTime)»; drop lineLimits when `dynamicTypeSize.isAccessibilitySize`.

**Test primero:** Dobacksoft TrainingTests/Features/ConvocatoriaHeaderCopyTests.swift: pure `accessibilityLabel(for:)` equals the expected sentence for the convocatorias-list fixture's first item.

#### 48. Metric rows stack vertically at accessibility text sizes (AnyLayout), no fixed-height dividers — *provisional*

**Severidad:** minor · **Esfuerzo:** M · **Lentes:** accessibility

**Archivos:** `Dobacksoft Training/Features/Standing/StandingView.swift`, `Dobacksoft Training/Features/Manager/StudentProfileView.swift`, `Dobacksoft Training Widgets/Dobacksoft_Training_Widgets.swift`

**Por qué importa:** Two/three metrics share one HStack with `Divider().frame(height: 28)`; at AX sizes «Nota pendiente de confirmación» wraps to 5-6 lines in a narrow column.

**Cambio propuesto:** `AnyLayout(dynamicTypeSize.isAccessibilitySize ? VStackLayout() : HStackLayout())` for the metric rows; replace fixed-height dividers with `Divider()` in the layout. Standing part PROVISIONAL.

**Test primero:** UI at `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` launch argument: `#expect(element("standing.card", in: app).frame.height > 0)` and the score label `isHittable` (not clipped).

#### 49. Widget uses the app's Fraunces/Inter via shared font factories

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** visual

**Archivos:** `Dobacksoft Training Widgets/Info.plist`, `SharedSnapshot/SharedTypography.swift`, `Dobacksoft Training Widgets/Dobacksoft_Training_Widgets.swift`

**Por qué importa:** The position number the candidate glances at most is SF Rounded on the home screen and Fraunces inside the app (Widgets.swift:232,245; widget Info.plist has no UIAppFonts).

**Cambio propuesto:** Add the .ttf files and `UIAppFonts` to the widget target; move `Font.display/body` factories into SharedSnapshot (SwiftUI-only, no app dependency); use `.display(size: 34, …, relativeTo: .largeTitle)` for the position. Do after item 24 so text styles remain Dynamic-Type aware.

**Test primero:** Dobacksoft TrainingTests/Theme/WidgetFontsTests.swift: read the widget Info.plist from the repo and `#expect(uiAppFonts.count == 8)`.

#### 50. DisclosureChevron component and a 2 pt spacing token (chevron/spacing literals) — *provisional*

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** visual

**Archivos:** `Dobacksoft Training/Shared/Theme/Theme+Modifiers.swift`, `Dobacksoft Training/Shared/Theme/Theme.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriaDetailView.swift`, `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`, `Dobacksoft Training/Features/Attempt/AttemptDetailView.swift`, `Dobacksoft Training/Features/Standing/StandingView.swift`

**Por qué importa:** Chevrons are `.caption` in two places and `.caption2` in four; `spacing: 2` recurs 12 times with no token; `Divider().padding(.leading, 52)` is a magic number.

**Cambio propuesto:** `DisclosureChevron` view (one font/colour/`accessibilityHidden`) used at all six sites; `Theme.spacing.xxs = 2`; express 52 as icon frame + spacing. Standing/ConvocatoriaDetail PROVISIONAL.

**Test primero:** Dobacksoft TrainingTests/Theme/ThemeTokensTests.swift: `#expect(Theme.spacing.xxs.value == 2)` and the scale is strictly increasing.

#### 51. Convocatorias in regular width: adaptive two-column grid of cards

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** ipad

**Archivos:** `Dobacksoft Training/Features/Convocatorias/ConvocatoriasListView.swift`

**Por qué importa:** An 800 pt single column of cards on iPad landscape; STUDENT lists are enrollment-scoped (usually one item), so the three-column split is mainly MANAGER value — the grid is the proportionate fix.

**Cambio propuesto:** Replace `LazyVStack` with `LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: 480))])`; keep push navigation.

**Test primero:** UI (iPad landscape): two `convocatorias.row` elements share the same `frame.minY` when the MANAGER staging account is used (XCTSkip if fewer than two rows).

#### 52. App Shortcut «Ver mi posición» once the deep link exists

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** native-craft

**Archivos:** `Dobacksoft Training/Shared/AppShortcuts.swift`

**Por qué importa:** The app is invisible to Siri/Spotlight beyond launch; cheap first-class signal after item 22.

**Cambio propuesto:** `AppShortcutsProvider` with one `OpenStandingIntent` (`openAppWhenRun = true`) setting `router.section = .miPosicion`; phrase «Ver mi posición en \(.applicationName)». No Spotlight indexing (exam data).

**Test primero:** Dobacksoft TrainingTests/Services/DeepLinkTests.swift: `OpenStandingIntent.route == .miPosicion` (pure mapping).

#### 53. Republish the widget snapshot on any app foreground (BGAppRefresh optional later)

**Severidad:** minor · **Esfuerzo:** L · **Lentes:** native-craft

**Archivos:** `Dobacksoft Training/Core/Auth/AuthSession.swift`, `Dobacksoft Training/Shared/SnapshotPublisher.swift`, `Dobacksoft Training/Info.plist`

**Por qué importa:** Only opening «Mi posición» republishes real figures; the widget ages honestly by design, so this is convenience. A deterministic foreground republish (using `RefreshTicker` from item 20 and the last-viewed convocatoria id in UserDefaults) closes most of the gap; `BGAppRefreshTask` is best-effort and can come later.

**Cambio propuesto:** Store `lastStandingConvocatoriaId` in app UserDefaults on publish; on `.active` with `isQuickViewEnabled`, fetch standing for it and publish. Later: `UIBackgroundModes: fetch` + `BGTaskScheduler` registration respecting the same flag.

**Test primero:** Dobacksoft TrainingTests/Snapshot/SnapshotPublisherTests.swift: with quick view disabled, `foregroundRefresh()` performs no `standing` call on FakeTrainingAPI; enabled → exactly one call with the stored id.

#### 54. MANAGER · Resultados table: scale column widths with Dynamic Type and grow the name column into the iPad pane

**Severidad:** important · **Esfuerzo:** M · **Lentes:** accessibility, ipad

**Archivos:** `Dobacksoft Training/Features/Resultados/ResultadosView.swift`

**Por qué importa:** Fixed 34/150/62 pt columns with `lineLimit(1)` clip three-digit positions and names at large text (ResultadosView.swift:70-73, 270-272, 295-297) and leave a blank strip on iPad; `proxy.size.width` is never read. Instructor-only, hence ranked after all STUDENT items.

**Cambio propuesto:** `@ScaledMetric(relativeTo: .subheadline)` for the three widths; `nameWidth = max(150, proxy.size.width - fixedColumns)`; `lineLimit(2)` when `dynamicTypeSize.isAccessibilitySize`. Longer term a native `Table` in regular width.

**Test primero:** Dobacksoft TrainingTests/Features/ResultadosLayoutTests.swift: pure `ResultadosColumns.nameWidth(available:circuitCount:)` — 1000 pt with 5 circuits → 1000 − (34 + 62 + 5×62 + paddings); 400 pt → 150 floor.

#### 55. MANAGER · Resultados VoiceOver: hide duplicate position cell, label «#» as «Puesto», hide «·» separators, «sin dato» for «—»

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** accessibility

**Archivos:** `Dobacksoft Training/Features/Resultados/ResultadosView.swift`

**Por qué importa:** Each row reads the position twice and the header speaks «almohadilla» (ResultadosView.swift:225, 206, 270, 287).

**Cambio propuesto:** `.accessibilityHidden(true)` on the position cell and «·» Texts; `.accessibilityLabel("Puesto")` on the header «#»; `.accessibilityLabel("sin dato")` where «—» stands for a missing value.

**Test primero:** Extend `accessibilityRowLabel` tests (add `ResultadosAccessibilityTests`) asserting the row label mentions «Puesto» exactly once.

#### 56. MANAGER · Panel polish: adaptive KPI grid, 44 pt search-clear button, hide «Ver todas» in regular width

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** ipad, accessibility

**Archivos:** `Dobacksoft Training/Features/Manager/ManagerPanelView.swift`

**Por qué importa:** Three fixed KPI columns at every width (ManagerPanelView.swift:324), a 17 pt clear glyph (:468), and «Ver todas» pushing a duplicate of a sidebar section on iPad (:634).

**Cambio propuesto:** `GridItem(.adaptive(minimum: 150, maximum: 240))`; `.frame(width: 44, height: 44).contentShape(Rectangle())` on the clear button (or `.searchable`); gate «Ver todas» on `horizontalSizeClass == .compact` until it can set `router.section`.

**Test primero:** UI on iPad: `#expect(!app.buttons["Ver todas"].exists)` in the Panel; on iPhone it exists.

#### 57. Project hygiene: remove Apple Watch (device family 4) from the four test configurations

**Severidad:** minor · **Esfuerzo:** S · **Lentes:** ipad

**Archivos:** `Dobacksoft Training.xcodeproj/project.pbxproj`

**Por qué importa:** D-IOS-003 retired watchOS, but `TARGETED_DEVICE_FAMILY = "1,2,4"` survives at pbxproj:729, 758, 786, 814.

**Cambio propuesto:** Change the four occurrences to `"1,2"`.

**Test primero:** Dobacksoft TrainingTests/Services/ProjectHygieneTests.swift: read project.pbxproj from the repo path and `#expect(!contents.contains("1,2,4"))` — cheap guard against Xcode reintroducing it.

---

## Necesita backend (fuera de este backlog)

- Attempt detail endpoint should include `createdAt` (today the date is threaded from the list only; manager entry points have none).
- Profile needs the organisation *name* (only `organizationId` is exposed) for web parity on «Perfil».
- Per-event deduction (`deduccion_nota` / `unidad_deduccion`) is not in the mobile event mapping; only the gravity `categoria` can be shown today.
- Routes catalog (code → name) so pending required routes can show a name, not just the code.
- In-progress/OPEN attempt state («Conducida … calculando la nota») is not returned by `/me/attempts` (CLOSED only); also blocks any Live Activity.
- GPS trace for the attempt (web draws the route) and PDF download of the attempt report.
- «Orientación pedagógica» text block shown on the web attempt page is not in the detail DTO.
- Profile editing, photo, «Datos administrativos» and PIN recovery (/mi-pin) have no mobile endpoints.

---

## Descartado por el escéptico

- **Rename «Plaza N» / «Nombre o plaza» (kiosk identifier) — two auditor claims** — Refuted by the skeptic and I agree: `plaza` singular is the kiosk enrolment number the portal itself labels «Plaza» / «Número de plaza» (perfil.html:154, mi_pin.html:54), documented as not a cupo (RankingDTO.swift:7-9). Renaming breaks parity with what the candidate types at the kiosk. Only the cupo-sense sentence «asignación de plaza» is in the backlog (item 2). Any freeze test must scope this identifier out.
- **Status bar hidden app-wide via INFOPLIST_KEY_UIStatusBarHidden** — Refuted with runtime evidence: view-controller-based appearance is the default and screenshots in the existing xcresult show the status bar; landscape iPhone hides it by system behaviour.
- **A11Y-17 «No test covers accessibility labels, Dynamic Type or contrast» as a standalone item** — Not discarded as a concern — folded into the `testFirst` of items 10 (WCAG ratio from colorsets), 17 (ScoreFormat.spoken), 19, 47 and 48 (AX-size UI assertions) so each fix carries its own regression test instead of one omnibus task.
- **V-19 «tolerancia admitida» as a separate blocker** — Skeptic downgraded to minor (an adjective on a scoring margin, not a verdict). Kept as a one-word reword inside item 2 because it is the same work (string sweep + freeze test); not tracked on its own.
- **NC-17 Live Activity for an ongoing attempt** — Needs an in-progress attempt endpoint; moved to needsBackend.
- **IPAD-03 three-column NavigationSplitView for Convocatorias (L)** — Downgraded to minor by the skeptic: STUDENT lists are enrollment-scoped (usually one item) and the push flow is native and functional. Kept only the proportionate S-effort adaptive grid (item 51); the three-column split is MANAGER value and not worth L today.
- **ST-03 option (a): cache UserDTO in Keychain** — Option (b) (restoreFailure + banner + retry) solves the visible problem with no new Keychain key or Codable conformance; (a) can be revisited with item 27.

---

## Cómo se produjo este documento

Workflow de cuatro fases: inventario de pantallas y estados → cinco auditores independientes con lentes distintas sobre el mismo código → un escéptico por cada hallazgo importante o bloqueante, con la consigna de refutar → síntesis en backlog con test-primero (TDD estricto en este repo). Los hallazgos menores no pasaron por escéptico. Los dos bloqueantes fueron re-verificados a mano contra el árbol de trabajo actual antes de publicar este documento.
