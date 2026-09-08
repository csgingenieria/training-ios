import SwiftUI

@MainActor
@Observable
final class StandingViewModel {
    enum State {
        case loading
        case loaded(StandingDTO)
        /// Con el motivo: no estar inscrito y no tener posición todavía son
        /// estados legítimos, no fallos, y se cuentan distinto.
        case notFound(NotFoundReason)
        case error(String)
    }

    var state: State = .loading

    /// Hay un refresco en curso SOBRE datos ya visibles.
    ///
    /// Distinto de `.loading`: ahí no hay nada que enseñar y toca la pantalla
    /// de carga; aquí la posición sigue en pantalla y lo único que procede es
    /// un indicador discreto.
    var isRefreshing = false

    /// El fallo del último refresco, cuando había datos que conservar.
    ///
    /// Aparte de `.error` a propósito: `.error` significa «no hay nada que
    /// enseñar», y esto significa «lo que hay es de antes». Meterlos en el
    /// mismo sitio es lo que hacía que un fallo de red pasajero borrase la nota
    /// que el aspirante estaba mirando.
    var refreshError: String?

    /// Cuándo se obtuvieron los datos que se están enseñando.
    ///
    /// La hora del DATO, no la del último intento de refrescarlo: si el
    /// refresco falla no se mueve, porque lo que hay en pantalla sigue siendo
    /// lo de antes.
    var lastUpdated: Date?

    private let api: TrainingAPI
    private let now: @Sendable () -> Date

    init(api: TrainingAPI = APIClient.shared, now: @escaping @Sendable () -> Date = Date.init) {
        self.api = api
        self.now = now
    }

    func load(
        convocatoriaId: String,
        auth: AuthSession,
        convocatoriaName: String? = nil,
        finality: GradeFinality = .unknown
    ) async {
        // Solo `.loaded` cuenta como «hay algo que proteger». `.notFound` es
        // una respuesta legítima, no un dato: conservarla ante un fallo
        // posterior enseñaría como vigente una ausencia que ya no consta.
        let teniaDatos: Bool
        if case .loaded = state { teniaDatos = true } else { teniaDatos = false }

        if teniaDatos { isRefreshing = true } else { state = .loading }
        defer { isRefreshing = false }

        do {
            let standing = try await auth.authorized { [api] token in
                try await api.standing(
                    convocatoriaId: convocatoriaId,
                    accessToken: token
                )
            }
            state = .loaded(standing)
            refreshError = nil
            lastUpdated = now()
        } catch let err as APIError where err.notFoundReason != nil {
            state = .notFound(err.notFoundReason ?? .resourceMissing)
        } catch {
            let mensaje = (error as? APIError)?.userMessage ?? error.localizedDescription
            if teniaDatos {
                refreshError = "\(mensaje) Se muestra el último dato consultado."
            } else {
                state = .error(mensaje)
            }
        }

        // La vista rápida se alimenta desde aquí. Un estado de error no
        // publica: un fallo de red pasajero no debe borrar el último dato bueno.
        if let content = SnapshotPublisher.content(
            for: state,
            convocatoriaName: convocatoriaName,
            finality: finality
        ) {
            SnapshotPublisher.shared.publish(content)
        }
    }
}

/// Cargando, centrado y con su propio fondo.
///
/// Función a nivel de fichero, no método de una vista: la usan varias pantallas
/// de este módulo. Vivía entre `StandingView` y `StandingCard` y se fue por
/// delante al borrar la primera.
@ViewBuilder
private func centeredLoading(_ text: String) -> some View {
    VStack(spacing: Theme.spacing.md.value) {
        ProgressView()
            .tint(Color.brand)
        Text(text)
            .font(.metaCaption)
            .foregroundStyle(Color.muted)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .pageBackground()
}

struct StandingCard: View {
    let standing: StandingDTO

    /// Si la nota ya es definitiva. Depende del estado de la CONVOCATORIA, que
    /// este DTO no trae: lo inyecta quien sí lo conoce.
    var finality: GradeFinality = .unknown

    var body: some View {
        VStack(spacing: Theme.spacing.lg.value) {
            VStack(spacing: Theme.spacing.xs.value) {
                Text("Puesto")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                Text("\(standing.position)")
                    .font(.heroNumber)
                    .foregroundStyle(Color.brand)
                    .accessibilityLabel("Puesto \(standing.position) de \(standing.totalCandidates)")
                Text("de \(standing.totalCandidates)")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }

            HStack(spacing: Theme.spacing.md.value) {
                StandingMetric(
                    title: finality.scoreLabel,
                    value: ScoreFormat.aggregate(standing.score)
                )
                // Sin fracción: `attemptsCompleted` cuenta recorridos de examen
                // distintos y `attemptsTotal` cuenta intentos. Son dos unidades
                // distintas, así que «2/4» no describe ningún progreso real, y
                // ninguno de los dos es el denominador de la nota.
                StandingMetric(
                    title: "Intentos registrados",
                    value: "\(standing.attemptsTotal)"
                )
            }

            if let composition = standing.composition {
                compositionBlock(composition)
            }

            if let note = finality.note {
                Text(note)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: Theme.spacing.xs.value) {
                let enrolment = StatusVocabulary.enrolment(standing.status)
                HStack(spacing: Theme.spacing.sm.value) {
                    Text("Estado de su matrícula")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                    StatusBadge(text: enrolment.label, kind: enrolment.kind)
                }
                // Una sola frase, en un solo sitio. La que había aquí usaba el
                // sentido de CUPO de una palabra que el documento de entrega
                // v1.1 le niega al cliente por escrito, y estaba justo debajo
                // de la posición del aspirante. La escribí yo; la cazó la
                // auditoría de la otra sesión.
                Text(LegalNotice.outcomeDecidedByCMadrid)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.spacing.lg.value)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                .fill(Color.paperElevated)
        )
        .themedShadow(.medium)
    }

    /// De qué está hecha la nota.
    ///
    /// Es la diferencia entre leer «4,75» y entender «4,75, que son cinco
    /// recorridos conducidos con un 9,50 de media más cinco que aún no has
    /// hecho y computan como cero». Sin esto, alguien concluye que conduce mal
    /// cuando lo que pasa es que va por la mitad del examen.
    @ViewBuilder
    private func compositionBlock(_ composition: GradeComposition) -> some View {
        // La explicación vive en `GradeCompositionView`, que comparten esta
        // pantalla y la de progreso: son cuatro números cuya redacción importa,
        // y dos copias se habrían separado a la primera corrección.
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            if !composition.isGlobalBest { Divider() }
            GradeCompositionView(composition: composition)
        }
    }
    
}

struct StandingMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.body(size: 18, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(Color.ink)
            Text(title)
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacing.md.value)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                .fill(Color.paper)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

private struct StudentAttemptRoute: Hashable {
    let attemptId: String

    /// Cuándo fue el intento. La lleva la fila de la lista y el detalle no la
    /// recibe del API, así que viaja en la ruta.
    var createdAt: String?
}

/// Tab del STUDENT en el dashboard: muestra saludo + selector de convocatorias
/// + standing + lista de intentos. Si tiene una sola, va directo a ella.
struct MyStandingTabView: View {
    @Environment(AuthSession.self) private var auth
    @State private var convocatorias: [ConvocatoriaSummaryDTO] = []
    @State private var selectedId: String?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var selectedConvocatoria: ConvocatoriaSummaryDTO? {
        convocatorias.first { $0.id == selectedId }
    }

    var body: some View {
        Group {
            if isLoading {
                centeredLoading("Cargando…")
            } else if let errorMessage {
                errorView(errorMessage)
            } else if convocatorias.isEmpty {
                emptyView
            } else if let selectedId, convocatorias.contains(where: { $0.id == selectedId }) {
                content(selectedId: selectedId)
            }
        }
        .navigationTitle("Mi posición")
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: Theme.spacing.lg.value) {
            greetingCard
            ContentUnavailableView(
                "Sin convocatorias",
                systemImage: "tray.fill",
                description: Text("Todavía no está inscrito en ninguna convocatoria.")
            )
        }
        .padding(.horizontal, Theme.spacing.base.value)
        .padding(.top, Theme.spacing.base.value)
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
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
        .navigationDestination(for: StudentAttemptRoute.self) { route in
            AttemptDetailView(
                attemptId: route.attemptId,
                convocatoriaName: selectedConvocatoria?.name,
                finality: GradeFinality(convocatoriaStatus: selectedConvocatoria?.status),
                convocatoriaClosedAt: selectedConvocatoria?.closedAt,
                createdAt: route.createdAt
            )
        }
    }

    @ViewBuilder
    private var greetingCard: some View {
        HStack(spacing: Theme.spacing.base.value) {
            ZStack {
                Circle().fill(Color.brandTint)
                Text((auth.user?.name.prefix(1) ?? "").uppercased())
                    .font(.display(size: 22, weight: .bold, italic: true, relativeTo: .title2))
                    .foregroundStyle(Color.brand)
            }
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Hola, \(auth.user?.name.components(separatedBy: " ").first ?? "")")
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                Text(StandingHeaderCopy.subtitle(
                    selected: selectedConvocatoria,
                    convocatorias: convocatorias
                ))
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
            Spacer()
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
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
            }
        }
    }

    @ViewBuilder
    private func convocatoriaChip(_ conv: ConvocatoriaSummaryDTO) -> some View {
        let isSelected = conv.id == selectedId
        Button {
            selectedId = conv.id
        } label: {
            Text(conv.name)
                .font(.body(size: 13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(isSelected ? .white : Color.ink)
                .padding(.horizontal, Theme.spacing.base.value)
                .padding(.vertical, Theme.spacing.sm.value)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.brand : Color.paperElevated)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(conv.name)
        .accessibilityValue(isSelected ? "seleccionada" : "no seleccionada")
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            convocatorias = try await auth.authorized { token in
                try await APIClient.shared.myConvocatorias(accessToken: token)
            }
            if selectedId == nil || !convocatorias.contains(where: { $0.id == selectedId }) {
                selectedId = convocatorias.first?.id
            }
        } catch let err as APIError {
            errorMessage = err.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
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
        .task(id: convocatoriaId) { await load() }
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
                refreshFooter
            }
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
                            .buttonStyle(.plain)
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
                Text("Filtros")
            }
            .font(.metaCaption)
            .foregroundStyle(Color.brand)
        }
        .accessibilityLabel("Filtros de intentos")
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

@MainActor
@Observable
final class MyAttemptsViewModel {
    enum State {
        case loading
        case loaded([AttemptSummaryDTO])
        case empty
        case error(String)
    }

    var state: State = .loading

    func load(convocatoriaId: String, auth: AuthSession) async {
        state = .loading
        do {
            let items = try await auth.authorized { token in
                try await APIClient.shared.myAttempts(
                    convocatoriaId: convocatoriaId,
                    accessToken: token
                )
            }
            state = items.isEmpty ? .empty : .loaded(items)
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

struct AttemptSummaryRow: View {
    let attempt: AttemptSummaryDTO

    var body: some View {
        HStack(spacing: Theme.spacing.md.value) {
            VStack(alignment: .leading, spacing: Theme.spacing.xs.value) {
                Text(attempt.route?.displayName ?? "Intento")
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                HStack(spacing: Theme.spacing.sm.value) {
                    if let date = APIDate.shortDateTime(attempt.createdAt) {
                        Text(date)
                            .font(.metaCaption)
                            .foregroundStyle(Color.muted)
                    }
                    if attempt.route?.isPractice == true {
                        // Ahora que el contrato manda la categoría, la app puede
                        // señalar qué intentos no cuentan para la nota. Antes
                        // solo podía poner una advertencia genérica en la lista.
                        StatusBadge(text: "Prácticas", kind: .neutral)
                    }
                    if let quality = attempt.quality {
                        StatusBadge(text: quality.label, kind: quality.badgeKind)
                    }
                }
            }
            Spacer()
            scoreView
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.muted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Theme.spacing.base.value)
        .padding(.vertical, Theme.spacing.md.value)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Tocar para ver detalle del intento")
    }

    @ViewBuilder
    private var scoreView: some View {
        // «Sin nota», no un guion. Es la regla que el widget lleva escrita
        // —«nunca un guion en lugar de una cifra»— y las palabras son las que
        // ya usa el filtro de intentos para este mismo caso.
        //
        // El guion además borraba una distinción que importa: «—» y «0,0»
        // significan lo contrario para quien se presenta a una oposición.
        Text(attempt.rowScoreText)
            .font(.body(size: attempt.hasScore ? 20 : 14, weight: .semibold, relativeTo: .title3))
            .foregroundStyle(attempt.hasScore ? Color.ink : Color.muted)
    }

}

// MARK: - Filtros locales para "Mis intentos"

enum AttemptSortMode: String, CaseIterable, Identifiable {
    case newestFirst
    case oldestFirst
    case scoreDescending
    case scoreAscending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newestFirst:     return "Más recientes"
        case .oldestFirst:     return "Más antiguos"
        case .scoreDescending: return "Mejor nota"
        case .scoreAscending:  return "Peor nota"
        }
    }

    var systemImage: String {
        switch self {
        case .newestFirst, .oldestFirst:           return "calendar"
        case .scoreDescending, .scoreAscending:    return "chart.bar"
        }
    }

    func apply(_ items: [AttemptSummaryDTO]) -> [AttemptSummaryDTO] {
        switch self {
        case .newestFirst:
            return items.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
        case .oldestFirst:
            return items.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
        case .scoreDescending:
            return items.sorted { ($0.score ?? -1) > ($1.score ?? -1) }
        case .scoreAscending:
            return items.sorted { ($0.score ?? Double.infinity) < ($1.score ?? Double.infinity) }
        }
    }
}

enum AttemptQualityFilter: String, CaseIterable, Identifiable {
    case all, high, medium, low

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:    return "Todas las calidades"
        case .high:   return "Calidad alta"
        case .medium: return "Calidad media"
        case .low:    return "Calidad baja"
        }
    }

    func matches(_ attempt: AttemptSummaryDTO) -> Bool {
        guard self != .all else { return true }
        let dq = (attempt.dataQuality ?? "").uppercased()
        switch self {
        case .all:    return true
        case .high:   return dq == "HIGH" || dq == "GOOD"
        case .medium: return dq == "MEDIUM" || dq == "OK"
        case .low:    return dq == "LOW" || dq == "BAD"
        }
    }
}

enum AttemptScoreFilter: String, CaseIterable, Identifiable {
    case all, scored, unscored

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:      return "Con y sin nota"
        case .scored:   return "Con nota"
        case .unscored: return "Sin nota"
        }
    }

    func matches(_ attempt: AttemptSummaryDTO) -> Bool {
        switch self {
        case .all:      return true
        case .scored:   return attempt.score != nil
        case .unscored: return attempt.score == nil
        }
    }
}
