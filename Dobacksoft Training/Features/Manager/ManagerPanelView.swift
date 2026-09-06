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
    var pendientes: [PendienteDeConducir] = []

    struct PendienteDeConducir: Identifiable, Hashable {
        let studentId: String
        let name: String
        let plaza: String?
        let convocatoriaName: String
        var id: String { studentId + "-" + convocatoriaName }
    }

    /// Cuántas convocatorias se consultan para armar la lista.
    ///
    /// El endpoint de ranking va a 30 peticiones por minuto y esta pantalla se
    /// refresca al tirar hacia abajo. Con un tope bajo la función es útil sin
    /// convertir un panel en una ráfaga de peticiones.
    private static let maxConvocatoriasConsultadas = 3

    /// Convocatorias consideradas "activas" para la sección de atajos.
    func activeConvocatorias(_ all: [ConvocatoriaSummaryDTO]) -> [ConvocatoriaSummaryDTO] {
        all.filter { conv in
            guard let status = conv.status?.uppercased() else { return true }
            return ["OPEN", "ACTIVE", "ACTIVA", "EN CURSO"].contains(status)
        }
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
            await loadPendientes(convocatorias: c, auth: auth)
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Deriva del ranking quién no ha conducido todavía.
    ///
    /// Un fallo aquí **no** rompe el panel: es información complementaria, y
    /// perder los KPIs por no poder leer un ranking sería un mal negocio.
    private func loadPendientes(
        convocatorias: [ConvocatoriaSummaryDTO],
        auth: AuthSession
    ) async {
        let objetivo = activeConvocatorias(convocatorias).prefix(Self.maxConvocatoriasConsultadas)
        guard !objetivo.isEmpty else {
            pendientes = []
            return
        }

        var acumulado: [PendienteDeConducir] = []
        for convocatoria in objetivo {
            do {
                let ranking = try await auth.authorized { token in
                    try await APIClient.shared.ranking(
                        convocatoriaId: convocatoria.id,
                        accessToken: token
                    )
                }
                acumulado += ranking.entries
                    .filter(\.hasNotDriven)
                    .compactMap { entry in
                        guard let id = entry.candidate.id, !id.isEmpty else { return nil }
                        return PendienteDeConducir(
                            studentId: id,
                            name: entry.candidate.name ?? "—",
                            plaza: entry.candidate.plaza,
                            convocatoriaName: convocatoria.name
                        )
                    }
            } catch {
                AppLog.api.notice(
                    "No se pudo leer el ranking de una convocatoria para la lista de pendientes: \(String(describing: error), privacy: .public)"
                )
            }
        }
        pendientes = acumulado
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
            KPICell(
                title: "Candidatos",
                value: "\(dashboard.totalCandidates)",
                icon: "person.3.fill",
                color: .success
            )
            KPICell(
                title: "Participantes",
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

                VStack(spacing: 0) {
                    ForEach(Array(viewModel.pendientes.prefix(10).enumerated()), id: \.offset) { index, pendiente in
                        NavigationLink(value: PanelStudentRoute(studentId: pendiente.studentId)) {
                            HStack(spacing: Theme.spacing.md.value) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pendiente.name)
                                        .font(.bodyEmphasis)
                                        .foregroundStyle(Color.ink)
                                    HStack(spacing: Theme.spacing.sm.value) {
                                        if let plaza = pendiente.plaza {
                                            Text("Plaza \(plaza)")
                                        }
                                        Text(pendiente.convocatoriaName)
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

                        if index < min(viewModel.pendientes.count, 10) - 1 {
                            Divider().padding(.leading, Theme.spacing.base.value)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                        .fill(Color.paperElevated)
                )
                .themedShadow(.small)

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
