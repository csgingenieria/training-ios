import SwiftUI

@MainActor
@Observable
final class StandingViewModel {
    enum State {
        case loading
        case loaded(StandingDTO)
        case notFound
        case error(String)
    }

    var state: State = .loading

    func load(
        convocatoriaId: String,
        auth: AuthSession,
        convocatoriaName: String? = nil,
        finality: GradeFinality = .unknown
    ) async {
        state = .loading
        do {
            let standing = try await auth.authorized { token in
                try await APIClient.shared.standing(
                    convocatoriaId: convocatoriaId,
                    accessToken: token
                )
            }
            state = .loaded(standing)
        } catch APIError.notFound {
            state = .notFound
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
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

struct StandingView: View {
    let convocatoriaId: String

    /// Estado de la convocatoria (`OPEN`, `CLOSED`…). Decide si la nota se
    /// rotula como provisional. Lo conoce quien navega hasta aquí.
    var convocatoriaStatus: String?

    /// Nombre de la convocatoria, para la vista rápida del widget.
    var convocatoriaName: String?

    @Environment(AuthSession.self) private var auth
    @State private var viewModel = StandingViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                centeredLoading("Cargando posición…")
            case .notFound:
                ContentUnavailableView(
                    "Todavía sin posición",
                    systemImage: "person.crop.circle.badge.questionmark",
                    // El backend devuelve el mismo 404 a quien no está inscrito
                    // y a quien lo está pero aún no ha conducido — el caso más
                    // común al abrir una convocatoria. Afirmar que no consta la
                    // inscripción era falso para el segundo, así que el texto
                    // cubre ambos sin dar por cierto ninguno.
                    description: Text("Su posición aparecerá cuando se registre el primer recorrido calificado.")
                )
            case .loaded(let standing):
                ScrollView {
                    StandingCard(
                        standing: standing,
                        finality: GradeFinality(convocatoriaStatus: convocatoriaStatus)
                    )
                        .padding(.horizontal, Theme.spacing.base.value)
                        .padding(.vertical, Theme.spacing.base.value)
                }
                .pageBackground()
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
        .navigationTitle("Mi posición")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        await viewModel.load(
            convocatoriaId: convocatoriaId,
            auth: auth,
            convocatoriaName: convocatoriaName,
            finality: GradeFinality(convocatoriaStatus: convocatoriaStatus)
        )
    }
}

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
                    value: String(format: "%.2f", standing.score)
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

            if let note = finality.note {
                Text(note)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: Theme.spacing.xs.value) {
                HStack(spacing: Theme.spacing.sm.value) {
                    Text("Estado de tu matrícula")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                    StatusBadge(text: standing.status, kind: badgeKind(for: standing.status))
                }
                Text("La asignación de plaza la decide CMadrid al cierre de la convocatoria.")
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

    private func badgeKind(for status: String) -> BadgeKind {
        switch status.uppercased() {
        case "ACTIVE", "ACTIVA": return .success
        case "WITHDRAWN", "INVALIDATED", "BAJA": return .danger
        default: return .neutral
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
                    embedded: true
                )
            }
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
        .navigationDestination(for: StudentAttemptRoute.self) { route in
            AttemptDetailView(attemptId: route.attemptId)
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
                Text(subtitleForCount(convocatorias.count))
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

    private func subtitleForCount(_ n: Int) -> String {
        switch n {
        case 0: return "Sin convocatorias activas"
        case 1: return "1 convocatoria activa"
        default: return "\(n) convocatorias activas"
        }
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
                .navigationDestination(for: StudentAttemptRoute.self) { route in
                    AttemptDetailView(attemptId: route.attemptId)
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
            StandingCard(
                standing: standing,
                finality: GradeFinality(convocatoriaStatus: convocatoriaStatus)
            )
        case .notFound:
            ContentUnavailableView(
                "Todavía sin posición",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("Su posición aparecerá cuando se registre el primer recorrido calificado.")
            )
            .cardStyle()
        case .error(let msg):
            VStack(spacing: Theme.spacing.sm.value) {
                Label("Error cargando posición", systemImage: "exclamationmark.triangle.fill")
                    .font(.cardTitle)
                    .foregroundStyle(Color.danger)
                Text(msg)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
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
                Text("Este listado recoge todos tus recorridos cerrados, prácticas incluidas. No todos intervienen en la nota oficial.")
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
                            NavigationLink(value: StudentAttemptRoute(attemptId: attempt.id)) {
                                AttemptSummaryRow(attempt: attempt)
                            }
                            .buttonStyle(.plain)
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
                Text("Todavía no hay intentos cerrados.")
                    .font(.bodyText)
                    .foregroundStyle(Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            case .error(let msg):
                Text(msg)
                    .font(.bodyText)
                    .foregroundStyle(Color.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                Text(attempt.route?.label ?? attempt.route?.id ?? "Intento")
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                HStack(spacing: Theme.spacing.sm.value) {
                    if let date = APIDate.shortDateTime(attempt.createdAt) {
                        Text(date)
                            .font(.metaCaption)
                            .foregroundStyle(Color.muted)
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
        if let s = attempt.score {
            Text(String(format: "%.2f", s))
                .font(.body(size: 20, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(Color.ink)
        } else {
            Text("—")
                .font(.body(size: 20, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(Color.muted)
        }
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
