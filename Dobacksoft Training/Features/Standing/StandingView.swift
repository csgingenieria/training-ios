import SwiftUI

/// Las dos vistas de «Mi posición»: la pestaña con el selector de
/// convocatoria, y el contenido de la convocatoria seleccionada.
///
/// Los demás tipos que vivían aquí están ahora en ficheros propios:
/// `StandingViewModel`, `StandingCard` y `AttemptListTypes`.

struct MyStandingTabView: View {
    @Environment(AuthSession.self) private var auth

    /// `withAnimation` explícito no lee el entorno por su cuenta —el
    /// modificador `animatedState` sí—, así que aquí hace falta a mano.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Opcional a propósito: las previsualizaciones no lo inyectan, y una
    /// pantalla no puede caerse por faltarle el motivo para recargar.
    @Environment(RefreshTicker.self) private var ticker: RefreshTicker?

    @State private var viewModel = MyStandingTabViewModel()

    private var convocatorias: [ConvocatoriaSummaryDTO] { viewModel.convocatorias }
    private var selectedConvocatoria: ConvocatoriaSummaryDTO? { viewModel.selectedConvocatoria }

    var body: some View {
        // Un solo enum, mutuamente excluyente. Eran tres banderas
        // independientes que podían decir «cargando», «error» y «aquí están
        // sus datos» a la vez, y el orden de estas ramas decidía qué mentira
        // ganaba: el error iba antes del contenido, así que un fallo pasajero
        // dejaba la pantalla principal del aspirante muerta para siempre.
        Group {
            switch viewModel.state {
            case .loading:
                LoadingStateView(text: "Cargando…")
            case .error(let mensaje):
                errorView(mensaje)
            case .empty:
                emptyView
            case .loaded:
                if let id = viewModel.selectedId {
                    content(selectedId: id)
                } else {
                    // No debería ocurrir —el view model reconcilia la
                    // selección con lo que llega—, pero una lista con datos y
                    // sin selección no puede quedarse en blanco.
                    emptyView
                }
            }
        }
        .transition(.opacity)
        // Fundido entre fases.
        //
        // La auditoría lo daba por descartado «por medición»: 139 s sin
        // animaciones frente a 304 s con el fundido. Ese número no aguanta.
        // Eran corridas únicas del recorrido entero, y el 2026-09-10 los
        // mismos dos tests, sobre código idéntico, dieron 65→83→135 s y
        // 39→50→75 s: la máquina se degrada dentro de una sesión, y una
        // corrida única mide su humor tanto como la app.
        //
        // Medido con `XCTClockMetric` —cinco iteraciones dentro de un mismo
        // lanzamiento, con desviación típica— en `ScreenTransitionBenchmark`:
        // sin fundido 6,35 · 7,55 · 8,98 s; con fundido 6,67 s. Cae dentro del
        // rango. Un 2,2× serían unos 15 s: excluido.
        //
        // Sobre `phase` y no sobre `state`: animar el estado completo exigiría
        // `Equatable` a cada DTO y volvería a animar cuando cambia una cifra
        // dentro de la fase cargada, que es cosa de `contentTransition`.
        .animation(Theme.motion.base, value: viewModel.phase)
        .navigationTitle("Mi posición")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Actualizar", systemImage: "arrow.clockwise") {
                    Task { await load() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .tint(Color.brand)
                .accessibilityIdentifier("standing.reload")
            }
        }
        // El destino vive en la RAÍZ, fuera del switch.
        //
        // Estaba dentro de `content(selectedId:)`, o sea dentro de la rama
        // `.loaded`: si esa rama se rerenderiza en el momento en que el enlace
        // dispara, el destino no está y el toque no empuja nada. Se veía como
        // un fallo intermitente contra staging —«el intento no abre», a
        // veces— y es el MISMO defecto que se corrigió esta mañana en la lista
        // de convocatorias y que aquí se quedó sin corregir.
        .navigationDestination(for: StudentAttemptRoute.self) { route in
            AttemptDetailView(
                attemptId: route.attemptId,
                convocatoriaName: selectedConvocatoria?.name,
                finality: GradeFinality(convocatoriaStatus: selectedConvocatoria?.status),
                convocatoriaClosedAt: selectedConvocatoria?.closedAt,
                createdAt: route.createdAt
            )
        }
        .task(id: ticker?.generation ?? 0) { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var emptyView: some View {
        // Dentro de un `ScrollView`: el `.refreshable` del cuerpo solo funciona
        // en un contenedor con scroll, y este vacío era un `VStack`. A quien
        // inscriben después de abrir la app se le quedaba esta pantalla puesta
        // y el gesto de tirar hacia abajo no hacía nada.
        ScrollView {
            VStack(spacing: Theme.spacing.lg.value) {
                greetingCard
                ContentUnavailableView {
                    Label("Sin convocatorias", systemImage: "tray.fill")
                } description: {
                    Text("Todavía no está inscrito en ninguna convocatoria.")
                } actions: {
                    // Y con botón, porque descubrir el gesto no puede ser el
                    // único camino: quien usa VoiceOver o Switch Control no lo
                    // tiene.
                    Button("Actualizar") { Task { await load() } }
                        .buttonStyle(.brandPrimary(fullWidth: false))
                        .accessibilityIdentifier("standing.refresh")
                }
            }
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.top, Theme.spacing.base.value)
            .containerRelativeFrame(.vertical, alignment: .top)
        }
        .pageBackground()
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text(message)
        } actions: {
            Button("Reintentar") { Task { await load() } }
                .buttonStyle(.brandPrimary(fullWidth: false))
        }
    }

    @ViewBuilder
    private func content(selectedId: String) -> some View {
        ScrollView {
            VStack(spacing: Theme.spacing.lg.value) {
                greetingCard
                if convocatorias.count > 1 {
                    convocatoriaPicker
                }
                MyConvocatoriaContentView(
                    convocatoriaId: selectedId,
                    convocatoriaStatus: selectedConvocatoria?.status,
                    convocatoriaName: selectedConvocatoria?.name,
                    convocatoriaClosedAt: selectedConvocatoria?.closedAt,
                    embedded: true
                )
            }
            .readableWidth()
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
    }

    @ViewBuilder
    private var greetingCard: some View {
        GreetingCard(
            name: auth.user?.name,
            subtitle: StandingHeaderCopy.subtitle(
                selected: selectedConvocatoria,
                convocatorias: convocatorias
            )
        )
    }

    @ViewBuilder
    private var convocatoriaPicker: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            Text("Convocatoria")
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
                .padding(.horizontal, Theme.spacing.xs.value)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.spacing.sm.value) {
                    ForEach(convocatorias) { conv in
                        convocatoriaChip(conv)
                    }
                }
                .padding(.horizontal, Theme.spacing.xs.value)
                .scrollTargetLayout()
            }
            // La elegida se trae a la vista. Con muchas convocatorias, la
            // seleccionada podía quedar fuera del scroll y la fila parecía no
            // tener ninguna puesta.
            .scrollPosition(id: selectedChipId, anchor: .center)
            // Un toque al cambiar de convocatoria: cambia TODA la pantalla de
            // abajo, y el chip recoloreándose es una señal pequeña para algo
            // tan grande.
            .sensoryFeedback(.selection, trigger: viewModel.selectedId)
            // Una sola parada de VoiceOver para la fila, con su nombre: sin
            // ella se recorre chip a chip sin saber qué son.
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Convocatoria")
        }
    }

    /// El id para `scrollPosition`, que pide un `Binding` opcional.
    private var selectedChipId: Binding<String?> {
        Binding(
            get: { viewModel.selectedId },
            // No escribe: el scroll no elige convocatoria. Dejar que lo hiciera
            // cambiaría la selección al arrastrar la fila, que es una acción
            // que la persona no ha pedido.
            set: { _ in }
        )
    }

    @ViewBuilder
    private func convocatoriaChip(_ conv: ConvocatoriaSummaryDTO) -> some View {
        let isSelected = conv.id == viewModel.selectedId
        Button {
            // Con curva: el chip recoloreaba de golpe y el cambio de
            // convocatoria —que cambia TODA la pantalla de abajo— no tenía
            // ninguna señal de que hubiera pasado algo.
            withAnimation(Motion.animation(Theme.motion.outStrong, reduceMotion: reduceMotion)) {
                viewModel.selectedId = conv.id
            }
        } label: {
            Text(conv.name)
                .font(.body(size: 13, weight: .semibold, relativeTo: .footnote))
                // `Color.onBrand` y no `.white`: ese token se creó justamente
                // para lo que va encima de `Color.brand`, y en modo oscuro el
                // blanco fijo no garantiza el contraste que él sí garantiza.
                // El chip se había quedado sin adoptarlo.
                .foregroundStyle(isSelected ? Color.onBrand : Color.ink)
                .padding(.horizontal, Theme.spacing.base.value)
                .padding(.vertical, Theme.spacing.sm.value)
                .frame(minHeight: 44)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.brand : Color.paperElevated)
                )
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(conv.name)
        // El RASGO nativo, no un valor de texto. VoiceOver dice «seleccionado»
        // en el idioma del sistema y con su entonación; «no seleccionada» como
        // valor obligaba además a oír la negación en cada chip que no lo está.
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }

    private func load() async {
        await viewModel.load(auth: auth)
    }
}

/// Contenido scrolleable del tab STUDENT: standing card + lista de intentos.
/// Tap en cualquier intento → AttemptDetailView.
///
/// Si `embedded == true`, el padre se encarga del `ScrollView`, `pageBackground`,
/// y `navigationDestination`. Esto permite componer este contenido dentro de un
/// dashboard con saludo + selector sin doble scroll.
struct MyConvocatoriaContentView: View {
    let convocatoriaId: String

    /// Estado de la convocatoria seleccionada, para rotular la nota.
    var convocatoriaStatus: String?

    /// Nombre de la convocatoria, para la vista rápida del widget.
    var convocatoriaName: String?

    /// Cuándo se cerró, para fechar la aclaración de la nota en el intento.
    var convocatoriaClosedAt: String?

    /// Opcional a propósito: las previsualizaciones no lo inyectan, y una
    /// pantalla no puede caerse por faltarle el motivo para recargar.
    @Environment(RefreshTicker.self) private var ticker: RefreshTicker?


    var embedded: Bool = false

    @Environment(AuthSession.self) private var auth
    @State private var standingVM = StandingViewModel()
    @State private var attemptsVM = MyAttemptsViewModel()

    @State private var sortMode: AttemptSortMode = .newestFirst
    @State private var qualityFilter: AttemptQualityFilter = .all
    @State private var scoreFilter: AttemptScoreFilter = .all

    var body: some View {
        Group {
            if embedded {
                inner
            } else {
                ScrollView {
                    inner
                        .readableWidth()
                        .padding(.horizontal, Theme.spacing.base.value)
                        .padding(.vertical, Theme.spacing.base.value)
                }
                .pageBackground()
                // Cuando esta vista es la pantalla —no un bloque dentro de
                // otra—, el título es suyo. Empotrada lo pone el padre
                // (`MyStandingTabView`); abierta desde el detalle de la
                // convocatoria no lo ponía nadie, y el aspirante veía un botón
                // de volver a secas sobre una pantalla sin nombre.
                .navigationTitle("Mi posición")
                .navigationDestination(for: StudentAttemptRoute.self) { route in
                    AttemptDetailView(
                        attemptId: route.attemptId,
                        convocatoriaName: convocatoriaName,
                        finality: GradeFinality(convocatoriaStatus: convocatoriaStatus),
                        convocatoriaClosedAt: convocatoriaClosedAt,
                        createdAt: route.createdAt
                    )
                }
            }
        }
        // Las dos mitades de la llave: la convocatoria elegida y el volver a
        // la app. Con solo una de ellas, la otra razón para recargar se pierde.
        .task(id: RefreshKey(id: convocatoriaId, generation: ticker?.generation ?? 0)) {
            await load()
        }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var inner: some View {
        VStack(spacing: Theme.spacing.lg.value) {
            standingSection
            attemptsSection
        }
    }

    @ViewBuilder
    private var standingSection: some View {
        switch standingVM.state {
        case .loading:
            HStack(spacing: Theme.spacing.md.value) {
                ProgressView().tint(Color.brand)
                Text("Cargando posición…")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .cardStyle()
        case .loaded(let standing):
            VStack(spacing: Theme.spacing.sm.value) {
                StandingCard(
                    standing: standing,
                    finality: GradeFinality(convocatoriaStatus: convocatoriaStatus)
                )
                attemptHighlights
                refreshFooter
            }
        case .cached(let cache, let capturedAt):
            // Lo último que se pudo leer, y dicho que lo es.
            //
            // Un aspirante en el garaje de un parque tenía antes la pantalla
            // vacía. Ahora tiene su puesto, con la fecha por delante: la cifra
            // sin la fecha sería peor que no tenerla, porque se leería como de
            // ahora.
            VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
                HStack(alignment: .top, spacing: Theme.spacing.sm.value) {
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(Color.muted)
                        .accessibilityHidden(true)
                    Text(SnapshotCopy.consultadoEl(capturedAt))
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                CachedStandingCard(cache: cache)
                Button("Reintentar") { Task { await standingVM.load(
                    convocatoriaId: convocatoriaId,
                    auth: auth,
                    convocatoriaName: convocatoriaName,
                    finality: GradeFinality(convocatoriaStatus: convocatoriaStatus)
                ) } }
                    .font(.metaCaption)
                    .foregroundStyle(Color.brand)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("standing.retryCached")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            .accessibilityIdentifier("standing.cached")
        case .notFound(let reason):
            ContentUnavailableView(
                reason.title,
                systemImage: reason.symbol,
                description: Text(reason.detail)
            )
            .cardStyle()
        case .error(let msg):
            // Con botón. Antes era una etiqueta roja y nada más: para volver a
            // intentarlo había que adivinar que la pantalla se tira hacia
            // abajo, y empotrada aquí ese gesto ni siquiera lo recoge esta
            // vista. El aspirante se quedaba mirando un error sin salida.
            ContentUnavailableView {
                Label("No se ha podido cargar su posición", systemImage: "exclamationmark.triangle.fill")
            } description: {
                Text(msg)
            } actions: {
                Button("Reintentar") { Task { await load() } }
                    .buttonStyle(.brandPrimary(fullWidth: false))
                    .accessibilityIdentifier("standing.retry")
            }
            .cardStyle()
        }
    }

    /// Lo que hay debajo de la posición cuando ya hay posición: si el último
    /// refresco falló, y de cuándo es el número que se está leyendo.
    ///
    /// Va aquí y no encima de la tarjeta a propósito. Un aviso sobre la
    /// tarjeta se lee como «esto de abajo está mal»; el dato no está mal,
    /// está fechado. Lo que se le debe al aspirante es la fecha, no una alarma.
    /// La fecha de la última vuelta y en qué recorrido va mejor y peor.
    ///
    /// Sale de los intentos que ya están cargados: ni una petición más. El
    /// portal los da y la tarjeta enseñaba solo la nota y la cuenta de
    /// intentos, teniéndolo todo en la mano.
    @ViewBuilder
    private var attemptHighlights: some View {
        if case .loaded(let attempts) = attemptsVM.state {
            let ultima = APIDate.shortDate(AttemptHighlights.lastAttemptDate(attempts))
            let extremos = AttemptHighlights.bestAndWorst(attempts)

            if ultima != nil || extremos != nil {
                VStack(alignment: .leading, spacing: Theme.spacing.xxs.value) {
                    if let ultima {
                        Text("Última vuelta: \(ultima)")
                    }
                    if let extremos {
                        // En neutro: señalar en rojo el recorrido «a mejorar»
                        // lo presentaría como un suspenso, y esto es dónde
                        // queda margen, no un veredicto.
                        Text("Mejor recorrido: \(extremos.best.code) (\(ScoreFormat.attempt(extremos.best.score)))"
                             + " · A mejorar: \(extremos.worst.code) (\(ScoreFormat.attempt(extremos.worst.score)))")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("standing.highlights")
            }
        }
    }

    @ViewBuilder
    private var refreshFooter: some View {
        if let refreshError = standingVM.refreshError {
            HStack(alignment: .top, spacing: Theme.spacing.sm.value) {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(Color.warning)
                    .accessibilityHidden(true)
                Text(refreshError)
                    .font(.metaCaption)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Reintentar") { Task { await load() } }
                    .font(.metaCaption)
                    .foregroundStyle(Color.brand)
                    // 44 pt de alto real: el rótulo son 12 pt y sin esto el
                    // objetivo táctil es la mitad del mínimo.
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("standing.retryRefresh")
            }
            .padding(.horizontal, Theme.spacing.base.value)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(refreshError)
        } else if let lastUpdated = standingVM.lastUpdated {
            HStack(spacing: Theme.spacing.xs.value) {
                if standingVM.isRefreshing {
                    ProgressView().controlSize(.mini).tint(Color.muted)
                }
                Text("Actualizado a las \(APIDate.time(lastUpdated))")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, Theme.spacing.base.value)
            .accessibilityIdentifier("standing.lastUpdated")
        }
    }

    @ViewBuilder
    private var attemptsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            HStack {
                Text("Mis intentos")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.ink)
                Spacer()
                if case .loaded = attemptsVM.state {
                    filtersMenu
                }
            }
            .padding(.horizontal, Theme.spacing.xs.value)

            // El backend avisa por escrito de que este listado NO se
            // corresponde con lo que compone la nota: incluye recorridos de
            // prácticas y cerrados sin nota. Y no manda la categoría del
            // recorrido, así que la app no puede señalar cuáles son cuáles;
            // adivinarlo por el código del recorrido está expresamente
            // desaconsejado. Se dice lo que se sabe, sin insinuar el resto.
            if case .loaded = attemptsVM.state {
                Text("Los recorridos marcados como prácticas se puntúan, pero no intervienen en la nota oficial.")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.spacing.xs.value)
            }

            switch attemptsVM.state {
            case .loading:
                HStack {
                    ProgressView().tint(Color.brand)
                    Text("Cargando intentos…")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
                .cardStyle()
            case .loaded(let items):
                let filtered = applyFiltersAndSort(items)
                if filtered.isEmpty {
                    VStack(spacing: Theme.spacing.sm.value) {
                        Text("Ningún intento coincide con los filtros.")
                            .font(.bodyText)
                            .foregroundStyle(Color.muted)
                        Button("Restablecer filtros") {
                            sortMode = .newestFirst
                            qualityFilter = .all
                            scoreFilter = .all
                        }
                        .font(.metaCaption)
                        .foregroundStyle(Color.brand)
                        // Mismo mínimo: es la única salida de una lista vacía
                        // por filtros, y su objetivo eran dos palabras en
                        // `metaCaption`.
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("attempts.resetFilters")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                } else {
                    VStack(spacing: 0) {
                        ForEach(filtered) { attempt in
                            NavigationLink(value: StudentAttemptRoute(
                                attemptId: attempt.id,
                                createdAt: attempt.createdAt
                            )) {
                                AttemptSummaryRow(attempt: attempt)
                            }
                            .buttonStyle(.card)
                            // Mantener pulsado no hacía nada en ninguna parte
                            // de la app. Compartir un intento es lo que un
                            // aspirante hace con él, y estaba a dos toques
                            // dentro de la ficha.
                            .contextMenu {
                                ShareLink(item: AttemptShareText.build(
                                    candidateName: nil,
                                    routeLabel: attempt.route?.displayName,
                                    score: attempt.score,
                                    quality: attempt.quality,
                                    createdAt: attempt.createdAt
                                ))
                            }
                            // Identidad estable para el recorrido automatizado:
                            // buscar la fila por su texto acabó tocando el menú
                            // de filtros, que también es un botón.
                            .accessibilityIdentifier("standing.attempt")
                            if attempt.id != filtered.last?.id {
                                Divider().padding(.leading, Theme.spacing.base.value)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                            .fill(Color.paperElevated)
                    )
                    .themedShadow(.small)
                    // Reordenar o filtrar movía las filas de golpe y la lista
                    // parecía otra que aparece de la nada. Se anima la LLAVE
                    // del orden, no los datos: llegar un intento nuevo del
                    // servidor no tiene que reacomodar la pantalla entera.
                    .animatedState(listOrderKey)
                }
            case .empty:
                // Con «Actualizar»: un aspirante que acaba de conducir abre la
                // app esperando ver su vuelta, y esta pantalla se cargó antes.
                // Sin control, la única salida era cerrar la app y volver.
                ContentUnavailableView {
                    Label("Todavía no hay intentos cerrados", systemImage: "tray.fill")
                } description: {
                    Text("Aquí aparecerán sus recorridos en cuanto queden calificados.")
                } actions: {
                    Button("Actualizar") { Task { await load() } }
                        .buttonStyle(.brandPrimary(fullWidth: false))
                        .accessibilityIdentifier("attempts.refresh")
                }
                .cardStyle()
            case .error(let msg):
                ContentUnavailableView {
                    Label("No se han podido cargar sus intentos", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(msg)
                } actions: {
                    Button("Reintentar") { Task { await load() } }
                        .buttonStyle(.brandPrimary(fullWidth: false))
                        .accessibilityIdentifier("attempts.retry")
                }
                .cardStyle()
            }
        }
    }

    @ViewBuilder
    private var filtersMenu: some View {
        Menu {
            Picker("Orden", selection: $sortMode) {
                ForEach(AttemptSortMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
            Picker("Calidad", selection: $qualityFilter) {
                ForEach(AttemptQualityFilter.allCases) { f in
                    Text(f.title).tag(f)
                }
            }
            Picker("Nota", selection: $scoreFilter) {
                ForEach(AttemptScoreFilter.allCases) { f in
                    Text(f.title).tag(f)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                // El rótulo dice cuántos filtros hay puestos: antes ponía
                // «Filtros» pasara lo que pasara, así que para saber si la
                // lista estaba completa había que abrir el menú.
                Text(AttemptFilterCopy.buttonLabel(quality: qualityFilter, score: scoreFilter))
            }
            .font(.metaCaption)
            .foregroundStyle(Color.brand)
            // 44 pt de alto y toda la zona tocable, no solo los glifos: el
            // rótulo va en `metaCaption` y su objetivo quedaba muy por debajo
            // del mínimo. Es el control con el que un instructor con guantes
            // filtra una tabla.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Filtros de intentos")
        // **Lo que faltaba de verdad.** El menú no decía si había algún filtro
        // puesto, así que quien usa VoiceOver veía una lista más corta de
        // vueltas sin manera de enterarse de que estaba filtrada — y podía
        // concluir que había conducido menos de las que condujo.
        .accessibilityValue(AttemptFilterCopy.spokenState(quality: qualityFilter, score: scoreFilter))
    }

    /// Lo que hace que reordenar o filtrar se lea como un movimiento y no como
    /// una lista distinta que aparece de golpe.
    private var listOrderKey: String {
        "\(sortMode.rawValue)-\(qualityFilter.rawValue)-\(scoreFilter.rawValue)"
    }

    private func applyFiltersAndSort(_ items: [AttemptSummaryDTO]) -> [AttemptSummaryDTO] {
        let filtered = items.filter { qualityFilter.matches($0) && scoreFilter.matches($0) }
        return sortMode.apply(filtered)
    }

    private func load() async {
        async let standing: Void = standingVM.load(
            convocatoriaId: convocatoriaId,
            auth: auth,
            convocatoriaName: convocatoriaName,
            finality: GradeFinality(convocatoriaStatus: convocatoriaStatus)
        )
        async let attempts: Void = attemptsVM.load(convocatoriaId: convocatoriaId, auth: auth)
        _ = await (standing, attempts)
    }
}
