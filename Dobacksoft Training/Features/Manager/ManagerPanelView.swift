import SwiftUI

/// El destino «ficha de este aspirante» dentro de la pila del panel.
///
/// Vive aquí, con la vista que lo empuja: es un detalle de navegación, no
/// estado del panel.
private struct PanelStudentRoute: Hashable {
    let studentId: String
}

/// El panel del instructor.
///
/// Su estado vive en `ManagerPanelViewModel` y sus destinos en
/// `PanelRoute`, cada uno en su fichero.
struct ManagerPanelView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Opcional a propósito: las previsualizaciones no lo inyectan, y una
    /// pantalla no puede caerse por faltarle el motivo para recargar.
    @Environment(RefreshTicker.self) private var ticker: RefreshTicker?

    @State private var viewModel = ManagerPanelViewModel()
    @State private var showSyncSheet = false
    @State private var studentQuery = ""

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingStateView(text: "Cargando panel…")
            case .loaded(let dashboard, let convocatorias):
                loadedContent(dashboard: dashboard, convocatorias: convocatorias)
            case .error(let msg):
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(msg)
                } actions: {
                    Button("Reintentar") { Task { await load() } }
                        .buttonStyle(.brandPrimary(fullWidth: false))
                }
            }
        }
        .navigationTitle("Panel")
        // Por VALOR y no por destino: con la pila de cada sección gestionada
        // por `DashboardRouter`, un enlace de destino empuja fuera de esa pila
        // y las pantallas que abre dejan de poder navegar por dentro.
        .navigationDestination(for: PanelRoute.self) { route in
            switch route {
            case .alertas:       WebfletAlertsView()
            case .convocatorias: ConvocatoriasListView()
            }
        }
        .task(id: ticker?.generation ?? 0) { await load() }
        .refreshable { await load() }
        .navigationDestination(for: PanelStudentRoute.self) { route in
            StudentProfileView(studentId: route.studentId)
        }
        .navigationDestination(for: ConvocatoriaSummaryDTO.self) { conv in
            ConvocatoriaDetailView(convocatoria: conv)
        }
        .sheet(isPresented: $showSyncSheet) {
            SyncResultSheet(viewModel: viewModel) {
                showSyncSheet = false
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func loadedContent(
        dashboard: ManagerDashboardDTO,
        convocatorias: [ConvocatoriaSummaryDTO]
    ) -> some View {
        ScrollView {
            VStack(spacing: Theme.spacing.lg.value) {
                greetingCard(dashboard: dashboard)
                primaryKPIs(dashboard: dashboard)
                activityKPIs(dashboard: dashboard)
                syncCard(dashboard: dashboard)
                alertsShortcut(lowQuality: dashboard.convocatoriasWithLowQuality)
                buscadorSection
                pendientesSection
                activeConvocatoriasSection(convocatorias: convocatorias)
            }
            .readableWidth()
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
    }

    @ViewBuilder
    private func greetingCard(dashboard: ManagerDashboardDTO) -> some View {
        GreetingCard(
            name: auth.user?.name,
            subtitle: subtitle(active: dashboard.activeConvocatorias)
        ) {
            // El distintivo es lo único que separa este saludo del del
            // aspirante: al instructor le importa con qué rol está mirando,
            // porque ve datos de otras personas.
            if let role = auth.user?.role {
                StatusBadge(text: StatusVocabulary.role(role), kind: .brand)
            }
        }
    }

    private func subtitle(active: Int) -> String {
        switch active {
        case 0:  return "Sin convocatorias activas"
        case 1:  return "1 convocatoria activa"
        default: return "\(active) convocatorias activas"
        }
    }

    @ViewBuilder
    private func primaryKPIs(dashboard: ManagerDashboardDTO) -> some View {
        // Adaptativa, no tres columnas fijas.
        //
        // Tres KPI forzados a tres columnas en un iPhone dejan cada cifra en
        // 100 pt con su rótulo partido en tres líneas; en un iPad, tres
        // tarjetas anchísimas con medio panel vacío. `.adaptive` decide cuántas
        // caben con el ancho que hay.
        let columns: [GridItem] = [
            GridItem(.adaptive(minimum: 150, maximum: 240), spacing: Theme.spacing.md.value)
        ]
        LazyVGrid(columns: columns, spacing: Theme.spacing.md.value) {
            KPICell(
                title: "Convocatorias",
                value: "\(dashboard.activeConvocatorias)",
                icon: "list.bullet.rectangle",
                color: .brand
            )
            // «Candidatos» y «Participantes», uno al lado del otro, con el
            // mismo número: dos rótulos casi iguales que no distinguían nada.
            // Coinciden mientras haya una sola convocatoria abierta y nadie de
            // baja, y divergen en cuanto eso cambia — momento en el que el
            // instructor no tendría forma de saber cuál es cuál.
            //
            // Lo que cuenta cada uno, según el backend:
            //   totalCandidates   = inscripciones ACTIVE en TODA la organización
            //   totalParticipants = inscritos en convocatorias OPEN, todo menos
            //                       INVALIDATED (así que incluye las bajas)
            KPICell(
                title: "Inscritos activos",
                value: "\(dashboard.totalCandidates)",
                icon: "person.3.fill",
                color: .success
            )
            KPICell(
                title: "En convocatorias abiertas",
                value: "\(dashboard.totalParticipants)",
                icon: "figure.walk",
                color: .warning
            )
        }
    }

    @ViewBuilder
    private func activityKPIs(dashboard: ManagerDashboardDTO) -> some View {
        // Adaptativa, no tres columnas fijas.
        //
        // Tres KPI forzados a tres columnas en un iPhone dejan cada cifra en
        // 100 pt con su rótulo partido en tres líneas; en un iPad, tres
        // tarjetas anchísimas con medio panel vacío. `.adaptive` decide cuántas
        // caben con el ancho que hay.
        let columns: [GridItem] = [
            GridItem(.adaptive(minimum: 150, maximum: 240), spacing: Theme.spacing.md.value)
        ]
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            Text("Actividad")
                .font(.sectionTitle)
                .foregroundStyle(Color.ink)
                .padding(.horizontal, Theme.spacing.xs.value)

            LazyVGrid(columns: columns, spacing: Theme.spacing.md.value) {
                KPICell(
                    title: "Intentos hoy",
                    value: "\(dashboard.attemptsToday)",
                    icon: "clock.fill",
                    color: .brand
                )
                KPICell(
                    title: "Esta semana",
                    value: "\(dashboard.attemptsThisWeek)",
                    icon: "calendar",
                    color: .neutral
                )
                KPICell(
                    title: "Calidad baja",
                    value: "\(dashboard.convocatoriasWithLowQuality)",
                    icon: "exclamationmark.triangle.fill",
                    color: dashboard.convocatoriasWithLowQuality > 0 ? .danger : .neutral
                )
            }
        }
    }

    @ViewBuilder
    private func syncCard(dashboard: ManagerDashboardDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.md.value) {
            HStack(spacing: Theme.spacing.md.value) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.body(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brand)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: Theme.spacing.xxs.value) {
                    Text("Última sincronización Webfleet")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                    Text(APIDate.shortDateTime(dashboard.lastWebfleetSyncAt) ?? "Sin datos sincronizados todavía")
                        .font(.bodyEmphasis)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
            }

            Button {
                Task { await runSync() }
            } label: {
                if viewModel.isSyncing {
                    HStack(spacing: Theme.spacing.sm.value) {
                        ProgressView().tint(Color.onBrand)
                        Text("Sincronizando…")
                    }
                } else {
                    HStack(spacing: Theme.spacing.sm.value) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sincronizar ahora")
                    }
                }
            }
            .buttonStyle(.brandPrimary)
            .disabled(viewModel.isSyncing)
            .accessibilityLabel(viewModel.isSyncing ? "Sincronizando" : "Sincronizar Webfleet ahora")
        }
        .cardStyle()
    }

    /// Buscador de aspirante por nombre o plaza.
    ///
    /// Antes solo se llegaba a una ficha sabiendo el puesto y abriendo el
    /// ranking. Un instructor que atiende a alguien en el parque necesita ir
    /// por su nombre, no por su posición.
    ///
    /// Filtra sobre el índice ya cargado: no hace peticiones al teclear.
    @ViewBuilder
    private var buscadorSection: some View {
        if !viewModel.aspirantes.isEmpty {
            VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
                Text("Buscar aspirante")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, Theme.spacing.xs.value)

                HStack(spacing: Theme.spacing.sm.value) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.muted)
                        .accessibilityHidden(true)
                    TextField("Nombre o plaza", text: $studentQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                    if !studentQuery.isEmpty {
                        Button {
                            studentQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.muted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Borrar búsqueda")
                    }
                }
                .padding(.horizontal, Theme.spacing.base.value)
                .padding(.vertical, Theme.spacing.md.value)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                        .fill(Color.paperElevated)
                )

                if let aviso = viewModel.coverage.aviso {
                    Text(aviso)
                        .font(.metaCaption)
                        .foregroundStyle(Color.warning)
                        .padding(.horizontal, Theme.spacing.xs.value)
                }

                if !studentQuery.isEmpty {
                    let resultados = viewModel.aspirantes.filter { $0.matches(studentQuery) }
                    if resultados.isEmpty {
                        // Sin resultados NO es lo mismo que «no está inscrito».
                        // Si el índice está incompleto, decirlo: la app no ha
                        // mirado en todas partes.
                        Text(
                            viewModel.coverage.esCompleta
                                ? "Ningún aspirante coincide con «\(studentQuery)»."
                                : "Ningún aspirante coincide entre los consultados. El índice está incompleto."
                        )
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                        .padding(.horizontal, Theme.spacing.xs.value)
                    } else {
                        aspiranteList(Array(resultados.prefix(12)))
                        if resultados.count > 12 {
                            Text("y \(resultados.count - 12) más. Afine la búsqueda.")
                                .font(.metaCaption)
                                .foregroundStyle(Color.muted)
                                .padding(.horizontal, Theme.spacing.xs.value)
                        }
                    }
                }
            }
        }
    }

    /// Filas de aspirante, compartidas por el buscador y por «sin conducir».
    @ViewBuilder
    private func aspiranteList(_ items: [ManagerPanelViewModel.Aspirante]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, aspirante in
                NavigationLink(value: PanelStudentRoute(studentId: aspirante.studentId)) {
                    HStack(spacing: Theme.spacing.md.value) {
                        VStack(alignment: .leading, spacing: Theme.spacing.xxs.value) {
                            Text(aspirante.name)
                                .font(.bodyEmphasis)
                                .foregroundStyle(Color.ink)
                            HStack(spacing: Theme.spacing.sm.value) {
                                if let plaza = aspirante.plaza {
                                    Text("Plaza \(plaza)")
                                }
                                Text(aspirante.convocatoriaName)
                                    .lineLimit(1)
                            }
                            .font(.metaCaption)
                            .foregroundStyle(Color.muted)
                        }
                        Spacer()
                        DisclosureChevron()
                    }
                    .padding(.horizontal, Theme.spacing.base.value)
                    .padding(.vertical, Theme.spacing.md.value)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Tocar para ver la ficha del aspirante")

                if index < items.count - 1 {
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

    /// Quién todavía no ha conducido.
    ///
    /// Junto a los KPIs de volumen, esta es la única lista accionable del
    /// panel: dice sobre quién hay que actuar hoy, no cuánto se hizo ayer.
    @ViewBuilder
    private var pendientesSection: some View {
        if !viewModel.pendientes.isEmpty {
            VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
                HStack {
                    Text("Todavía sin conducir")
                        .font(.sectionTitle)
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Text("\(viewModel.pendientes.count)")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                .padding(.horizontal, Theme.spacing.xs.value)

                aspiranteList(Array(viewModel.pendientes.prefix(10)))

                if viewModel.pendientes.count > 10 {
                    Text("y \(viewModel.pendientes.count - 10) más")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                        .padding(.horizontal, Theme.spacing.xs.value)
                }
            }
        }
    }

    @ViewBuilder
    private func alertsShortcut(lowQuality: Int) -> some View {
        NavigationLink(value: PanelRoute.alertas) {
            HStack(spacing: Theme.spacing.md.value) {
                Image(systemName: "bell.badge.fill")
                    .font(.body(size: 18, weight: .semibold))
                    .foregroundStyle(lowQuality > 0 ? Color.danger : Color.brand)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: Theme.spacing.xxs.value) {
                    Text("Alertas Webfleet")
                        .font(.bodyEmphasis)
                        .foregroundStyle(Color.ink)
                    Text("Incidencias de enriquecimiento de la flota")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                Spacer()
                DisclosureChevron()
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Tocar para ver alertas")
    }

    @ViewBuilder
    private func activeConvocatoriasSection(convocatorias: [ConvocatoriaSummaryDTO]) -> some View {
        let actives = viewModel.activeConvocatorias(convocatorias)
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            HStack {
                Text("Convocatorias activas")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.ink)
                Spacer()
                // «Ver todas» solo en compacto: en ancho regular la lista de
                // convocatorias ya está en el sidebar, a un toque, y el enlace
                // ofrece un segundo camino a lo mismo desde la misma pantalla.
                if !convocatorias.isEmpty, sizeClass != .regular {
                    NavigationLink(value: PanelRoute.convocatorias) {
                        Text("Ver todas")
                            .font(.metaCaption)
                            .foregroundStyle(Color.brand)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("panel.verTodas")
                }
            }
            .padding(.horizontal, Theme.spacing.xs.value)

            if actives.isEmpty {
                Text("No hay convocatorias activas en este momento.")
                    .font(.bodyText)
                    .foregroundStyle(Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            } else {
                VStack(spacing: Theme.spacing.md.value) {
                    ForEach(actives) { conv in
                        NavigationLink(value: conv) {
                            ConvocatoriaRow(conv: conv)
                        }
                        .buttonStyle(.card)
                        // Identificador PROPIO, distinto del de la lista de
                        // convocatorias. Compartirlo parecía elegante —es la
                        // misma convocatoria por otro camino— y volvía la
                        // consulta ambigua: un TabView mantiene las dos
                        // pantallas en la jerarquía, así que `firstMatch`
                        // devolvía la fila del panel estando en la lista, y no
                        // era tocable. Dos pantallas, dos nombres.
                        .accessibilityIdentifier("panel.convocatoria")
                    }
                }
            }
        }
    }

    private func load() async {
        await viewModel.load(auth: auth)
    }

    private func runSync() async {
        await viewModel.triggerSync(auth: auth)
        showSyncSheet = true
    }
}

private struct KPICell: View {
    let title: String
    let value: String
    let icon: String
    let color: BadgeKind

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            HStack {
                Image(systemName: icon)
                    .font(.body(size: 14, weight: .semibold))
                    .foregroundStyle(color.foreground)
                Spacer()
            }
            Text(value)
                .font(.metricValueLarge)
                .foregroundStyle(Color.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacing.md.value)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                .fill(Color.paperElevated)
        )
        .themedShadow(.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Sheet de resultado de sync

private struct SyncResultSheet: View {
    let viewModel: ManagerPanelViewModel
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing.lg.value) {
                    if let result = viewModel.syncResult {
                        successContent(result: result)
                    } else if let message = viewModel.syncErrorMessage {
                        errorContent(message: message)
                    } else {
                        // Inesperado — caer al estado neutro.
                        Text("Sin información del sync.")
                            .font(.bodyText)
                            .foregroundStyle(Color.muted)
                    }
                }
                .readableWidth()
                .padding(.horizontal, Theme.spacing.base.value)
                .padding(.vertical, Theme.spacing.lg.value)
            }
            .pageBackground()
            .navigationTitle("Sincronización Webfleet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar", action: onClose)
                        .foregroundStyle(Color.brand)
                }
            }
        }
    }

    @ViewBuilder
    private func successContent(result: SyncResultDTO) -> some View {
        VStack(spacing: Theme.spacing.md.value) {
            Image(systemName: result.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.heroGlyph)
                .foregroundStyle(result.ok ? Color.success : Color.warning)
            Text(result.ok ? "Sincronización completada" : "Sincronización con incidencias")
                .font(.sectionTitle)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)

        if !result.ftp.isEmpty {
            countersCard(title: "FTP pickup", counters: result.ftp)
        }
        if !result.webfleet.isEmpty {
            countersCard(title: "Webfleet sync", counters: result.webfleet)
        }
    }

    @ViewBuilder
    private func errorContent(message: String) -> some View {
        VStack(spacing: Theme.spacing.md.value) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.heroGlyph)
                .foregroundStyle(Color.danger)
            Text("No se pudo sincronizar")
                .font(.sectionTitle)
                .foregroundStyle(Color.ink)
            Text(message)
                .font(.bodyText)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.spacing.lg.value)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func countersCard(title: String, counters: [String: SyncCounter]) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            Text(title)
                .font(.cardTitle)
                .foregroundStyle(Color.ink)
            VStack(spacing: 0) {
                ForEach(counters.keys.sorted(), id: \.self) { key in
                    HStack {
                        Text(key)
                            .font(.bodyText)
                            .foregroundStyle(Color.inkSecondary)
                        Spacer()
                        Text(counters[key]?.display ?? "—")
                            .font(.bodyEmphasis)
                            .foregroundStyle(Color.ink)
                    }
                    .padding(.vertical, Theme.spacing.sm.value)
                    if key != counters.keys.sorted().last {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
