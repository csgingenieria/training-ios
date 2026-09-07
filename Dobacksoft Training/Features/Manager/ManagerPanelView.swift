import SwiftUI
import os

private struct PanelStudentRoute: Hashable {
    let studentId: String
}

@MainActor
@Observable
final class ManagerPanelViewModel {
    enum State {
        case loading
        case loaded(ManagerDashboardDTO, [ConvocatoriaSummaryDTO])
        case error(String)
    }

    var state: State = .loading

    // Sync de flota (POST /me/webfleet/sync) — feedback inline + sheet.
    var isSyncing: Bool = false
    var syncResult: SyncResultDTO?
    var syncErrorMessage: String?

    /// Inscritos que todavía no han conducido ningún recorrido, con la
    /// convocatoria a la que pertenecen.
    ///
    /// Es la lista que dirige el día del instructor y la web la tiene en su
    /// panel. No hace falta endpoint nuevo: el backend emite `position: null`
    /// exactamente para quien no ha conducido, así que el ranking ya lo dice.
    var pendientes: [Aspirante] { aspirantes.filter { !$0.haConducido } }

    /// Todos los inscritos de las convocatorias consultadas.
    ///
    /// Alimenta dos cosas con una sola lectura: la lista de quién no ha
    /// conducido y el buscador. Llegar a la ficha de alguien exigía saber su
    /// puesto y abrir el ranking; con esto se busca por nombre o por plaza.
    var aspirantes: [Aspirante] = []

    /// Qué parte del censo se pudo indexar.
    ///
    /// El índice sale de leer rankings, y eso puede quedarse corto por el tope
    /// de consultas o por un fallo de red. Sin este dato la app diría «ningún
    /// aspirante coincide» y «sin conducir: 18» como si fueran hechos, cuando
    /// son el resultado de no haber mirado. Afirmar un número sobre un grupo de
    /// personas que no se ha medido es justo lo que este proyecto no hace.
    struct IndexCoverage: Equatable {
        var consultadas: Int = 0
        var disponibles: Int = 0
        var fallidas: Int = 0

        var esCompleta: Bool { fallidas == 0 && consultadas >= disponibles }

        var aviso: String? {
            guard !esCompleta else { return nil }
            // Fallaron TODAS las que se intentaron: no hay índice, no un
            // índice corto. `consultadas` cuenta intentos, no éxitos.
            if fallidas > 0 && fallidas >= consultadas {
                return "No se ha podido consultar el censo de aspirantes."
            }
            let leidas = consultadas - fallidas
            return "Índice parcial: \(leidas) de \(disponibles) convocatorias en curso."
        }
    }

    var coverage = IndexCoverage()

    struct Aspirante: Identifiable, Hashable {
        let studentId: String
        let name: String
        let plaza: String?
        let convocatoriaName: String
        let haConducido: Bool
        var id: String { studentId + "-" + convocatoriaName }

        /// Compara ignorando tildes y mayúsculas.
        ///
        /// Muñoz, Núñez, Pérez y Martínez cubren buena parte de un censo
        /// español, y en el teclado del móvil se escriben sin tilde. Sin este
        /// plegado, buscar «Munoz» respondía que nadie coincide.
        func matches(_ query: String) -> Bool {
            let needle = Self.fold(query)
            guard !needle.isEmpty else { return true }
            return Self.fold(name).contains(needle)
                || Self.fold(plaza ?? "").contains(needle)
        }

        private static func fold(_ value: String) -> String {
            value
                .trimmingCharacters(in: .whitespaces)
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
        }
    }

    /// Cuántas convocatorias se consultan para armar la lista.
    ///
    /// El endpoint de ranking va a 30 peticiones por minuto y esta pantalla se
    /// refresca al tirar hacia abajo. Con un tope bajo la función es útil sin
    /// convertir un panel en una ráfaga de peticiones.
    private static let maxConvocatoriasConsultadas = 3

    /// Convocatorias en curso.
    ///
    /// Usa la misma definición que la lista de convocatorias (`ConvocatoriaScope`)
    /// para que «en curso» no signifique dos cosas distintas en la misma app.
    /// La lista blanca anterior dejaba fuera `PREVIEW` y `CLOSING` —estados
    /// reales del backend—, así que una convocatoria en pleno cierre perdía a
    /// sus aspirantes del buscador justo cuando hacían falta.
    func activeConvocatorias(_ all: [ConvocatoriaSummaryDTO]) -> [ConvocatoriaSummaryDTO] {
        all.filter(ConvocatoriaScope.activas.matches)
    }

    func load(auth: AuthSession) async {
        state = .loading
        do {
            // Dashboard + convocatorias en paralelo: agregados del backend +
            // lista para la sección "Convocatorias activas".
            //
            // Ambas van dentro de la misma llamada autorizada: si el token
            // caduca, se refresca una vez y se reintentan las dos juntas.
            let (d, c) = try await auth.authorized { token in
                async let dashboard = APIClient.shared.managerDashboard(accessToken: token)
                async let convs = APIClient.shared.convocatorias(accessToken: token)
                return try await (dashboard, convs)
            }
            state = .loaded(d, c)
            await loadAspirantes(convocatorias: c, auth: auth)
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Indexa a los inscritos de las convocatorias activas.
    ///
    /// Un fallo aquí **no** rompe el panel: es información complementaria, y
    /// perder los KPIs por no poder leer un ranking sería un mal negocio.
    private func loadAspirantes(
        convocatorias: [ConvocatoriaSummaryDTO],
        auth: AuthSession
    ) async {
        let activas = activeConvocatorias(convocatorias)
        let objetivo = activas.prefix(Self.maxConvocatoriasConsultadas)
        coverage = IndexCoverage(consultadas: objetivo.count, disponibles: activas.count)

        guard !objetivo.isEmpty else {
            aspirantes = []
            return
        }

        var acumulado: [Aspirante] = []
        for convocatoria in objetivo {
            do {
                let ranking = try await auth.authorized { token in
                    try await APIClient.shared.ranking(
                        convocatoriaId: convocatoria.id,
                        accessToken: token
                    )
                }
                acumulado += ranking.entries.compactMap { entry in
                    guard let id = entry.candidate.id, !id.isEmpty else { return nil }
                    return Aspirante(
                        studentId: id,
                        name: entry.candidate.name ?? "—",
                        plaza: entry.candidate.plaza,
                        convocatoriaName: convocatoria.name,
                        haConducido: !entry.hasNotDriven
                    )
                }
            } catch {
                coverage.fallidas += 1
                AppLog.api.notice(
                    "No se pudo leer el ranking de una convocatoria para el índice de aspirantes: \(String(describing: error), privacy: .public)"
                )
            }
        }
        aspirantes = acumulado
    }

    /// Dispara sync on-demand. Backend rate-limit 3/min — si vuelve 429 lo
    /// mostramos como error sin reintentar.
    func triggerSync(auth: AuthSession) async {
        isSyncing = true
        syncResult = nil
        syncErrorMessage = nil
        defer { isSyncing = false }

        do {
            let result = try await auth.authorized { token in
                try await APIClient.shared.webfletSync(accessToken: token)
            }
            syncResult = result
            // Tras sync exitoso, refrescamos el dashboard para que los KPIs
            // (intentos hoy, última sync) reflejen el cambio.
            await load(auth: auth)
        } catch APIError.rateLimited(let retryAfter) {
            if let retryAfter, retryAfter > 0 {
                syncErrorMessage = "Demasiadas peticiones. Inténtelo de nuevo en \(retryAfter) segundos."
            } else {
                syncErrorMessage = "Demasiadas peticiones. Espere un minuto antes de volver a intentarlo."
            }
        } catch let err as APIError {
            syncErrorMessage = err.userMessage
        } catch {
            syncErrorMessage = error.localizedDescription
        }
    }
}

struct ManagerPanelView: View {
    @Environment(AuthSession.self) private var auth
    @State private var viewModel = ManagerPanelViewModel()
    @State private var showSyncSheet = false
    @State private var studentQuery = ""

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                centeredLoadingPanel
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
        .task { await load() }
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
    private var centeredLoadingPanel: some View {
        VStack(spacing: Theme.spacing.md.value) {
            ProgressView().tint(Color.brand)
            Text("Cargando panel…")
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pageBackground()
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
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
    }

    @ViewBuilder
    private func greetingCard(dashboard: ManagerDashboardDTO) -> some View {
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
                Text(subtitle(active: dashboard.activeConvocatorias))
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
            Spacer()
            if let role = auth.user?.role {
                StatusBadge(text: role.uppercased(), kind: .brand)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
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
        let columns: [GridItem] = [
            GridItem(.flexible(), spacing: Theme.spacing.md.value),
            GridItem(.flexible(), spacing: Theme.spacing.md.value),
            GridItem(.flexible(), spacing: Theme.spacing.md.value),
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
        let columns: [GridItem] = [
            GridItem(.flexible(), spacing: Theme.spacing.md.value),
            GridItem(.flexible(), spacing: Theme.spacing.md.value),
            GridItem(.flexible(), spacing: Theme.spacing.md.value),
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
                VStack(alignment: .leading, spacing: 2) {
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
                        ProgressView().tint(.white)
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
                        VStack(alignment: .leading, spacing: 2) {
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
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.muted)
                            .accessibilityHidden(true)
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
        NavigationLink {
            WebfletAlertsView()
        } label: {
            HStack(spacing: Theme.spacing.md.value) {
                Image(systemName: "bell.badge.fill")
                    .font(.body(size: 18, weight: .semibold))
                    .foregroundStyle(lowQuality > 0 ? Color.danger : Color.brand)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alertas Webfleet")
                        .font(.bodyEmphasis)
                        .foregroundStyle(Color.ink)
                    Text("Incidencias de enriquecimiento de la flota")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.muted)
                    .accessibilityHidden(true)
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
                if !convocatorias.isEmpty {
                    NavigationLink {
                        ConvocatoriasListView()
                    } label: {
                        Text("Ver todas")
                            .font(.metaCaption)
                            .foregroundStyle(Color.brand)
                    }
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
                        .buttonStyle(.plain)
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
                .font(.display(size: 28, weight: .bold, italic: false, relativeTo: .title))
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
                .font(.system(size: 56))
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
                .font(.system(size: 56))
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
