import SwiftUI

private struct AttemptRoute: Hashable {
    let attemptId: String
}

private struct StudentProfileRoute: Hashable {
    let studentId: String
}

@MainActor
@Observable
final class RankingViewModel {
    enum State {
        case loading
        case loaded(RankingResponseDTO)
        case empty
        case error(String)
    }

    var state: State = .loading

    func load(convocatoriaId: String, auth: AuthSession) async {
        state = .loading
        do {
            let response = try await auth.authorized { token in
                try await APIClient.shared.ranking(
                    convocatoriaId: convocatoriaId,
                    accessToken: token
                )
            }
            state = response.entries.isEmpty ? .empty : .loaded(response)
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

enum RankingSortMode: String, CaseIterable, Identifiable {
    case position
    case scoreDescending
    case attemptsDescending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .position:           return "Por puesto"
        case .scoreDescending:    return "Mejor nota"
        case .attemptsDescending: return "Más intentos completados"
        }
    }

    func apply(_ entries: [RankingEntryDTO]) -> [RankingEntryDTO] {
        switch self {
        case .position:
            // Quien no ha conducido no tiene puesto: va al final de la lista,
            // no al principio como si fuera el puesto cero.
            return entries.sorted { ($0.position ?? .max) < ($1.position ?? .max) }
        case .scoreDescending:
            return entries.sorted { ($0.displayScore ?? -1) > ($1.displayScore ?? -1) }
        case .attemptsDescending:
            return entries.sorted { $0.attemptsCompleted > $1.attemptsCompleted }
        }
    }
}

struct RankingView: View {
    let convocatoriaId: String
    @Environment(AuthSession.self) private var auth
    @State private var viewModel = RankingViewModel()
    @State private var searchText = ""
    @State private var sortMode: RankingSortMode = .position

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                VStack(spacing: Theme.spacing.md.value) {
                    ProgressView().tint(Color.brand)
                    Text("Cargando ranking…")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .pageBackground()
            case .empty:
                ContentUnavailableView(
                    "Ranking vacío",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Todavía no hay entradas en esta convocatoria.")
                )
            case .loaded(let response):
                let filtered = filter(response.entries)
                let sorted = sortMode.apply(filtered)
                if sorted.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    loadedList(
                        response: response,
                        displayedEntries: sorted
                    )
                }
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
        .navigationTitle("Ranking")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Buscar candidato")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var sortMenu: some View {
        Menu {
            Picker("Orden", selection: $sortMode) {
                ForEach(RankingSortMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundStyle(Color.brand)
        }
        .accessibilityLabel("Cambiar orden del ranking")
    }

    private func filter(_ entries: [RankingEntryDTO]) -> [RankingEntryDTO] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return entries }
        return entries.filter { entry in
            (entry.candidate.name?.lowercased().contains(query) ?? false) ||
            (entry.candidate.plaza?.lowercased().contains(query) ?? false)
        }
    }

    @ViewBuilder
    private func loadedList(response: RankingResponseDTO, displayedEntries: [RankingEntryDTO]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(Array(displayedEntries.enumerated()), id: \.element.id) { idx, entry in
                        let isLast = idx == displayedEntries.count - 1
                        rowOrLink(entry: entry)
                        if !isLast {
                            Divider().padding(.leading, Theme.spacing.lg.value)
                        }
                    }
                } header: {
                    rankingHeader(response, shown: displayedEntries.count)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                    .fill(Color.paperElevated)
            )
            .themedShadow(.small)
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
        .navigationDestination(for: AttemptRoute.self) { route in
            AttemptDetailView(attemptId: route.attemptId)
        }
        .navigationDestination(for: StudentProfileRoute.self) { route in
            StudentProfileView(studentId: route.studentId)
        }
    }

    @ViewBuilder
    private func rowOrLink(entry: RankingEntryDTO) -> some View {
        // Preferimos navegar al perfil del alumno (vista MANAGER/ADMIN más útil).
        // Si no hay candidate.id, fallback al detalle del intento. Si no hay
        // ninguno, queda como row plana sin tap.
        if let candidateId = entry.candidate.id, !candidateId.isEmpty {
            NavigationLink(value: StudentProfileRoute(studentId: candidateId)) {
                RankingEntryRow(entry: entry)
            }
            .buttonStyle(.plain)
        } else if let attemptId = entry.attemptId, !attemptId.isEmpty {
            NavigationLink(value: AttemptRoute(attemptId: attemptId)) {
                RankingEntryRow(entry: entry)
            }
            .buttonStyle(.plain)
        } else {
            RankingEntryRow(entry: entry)
        }
    }

    @ViewBuilder
    private func rankingHeader(_ response: RankingResponseDTO, shown: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.xs.value) {
            Text(response.convocatoria.name)
                .font(.cardTitle)
                .foregroundStyle(Color.ink)
            HStack(spacing: Theme.spacing.sm.value) {
                if shown != response.entries.count {
                    Text("\(shown) de \(response.entries.count) candidatos")
                } else {
                    Text("\(response.entries.count) candidatos")
                }
            }
            .font(.metaCaption)
            .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.spacing.base.value)
        .padding(.vertical, Theme.spacing.md.value)
        .background(Color.paperElevated)
    }

    private func load() async {
        await viewModel.load(convocatoriaId: convocatoriaId, auth: auth)
    }
}

struct RankingEntryRow: View {
    let entry: RankingEntryDTO

    var body: some View {
        HStack(spacing: Theme.spacing.md.value) {
            positionBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.candidate.name ?? "—")
                    .font(.bodyEmphasis)
                    .foregroundStyle(Color.ink)
                if let plaza = entry.candidate.plaza {
                    Text("Plaza \(plaza)")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                scoreText
                Text("\(entry.attemptsTotal) intentos")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
            if entry.attemptId != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.muted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Theme.spacing.base.value)
        .padding(.vertical, Theme.spacing.md.value)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    /// Every position gets the same treatment.
    ///
    /// Colouring the badge by `position <= plazas` drew a cut-off line on
    /// screen: brand fill for "in", grey for "out". The system awards no verdict
    /// and manages no seats, so the ranking must not imply one. RGPD art. 22.
    private var positionBadge: some View {
        Text(entry.position.map(String.init) ?? "—")
            .font(.body(size: 16, weight: .bold, relativeTo: .headline))
            .foregroundStyle(entry.hasNotDriven ? Color.muted : Color.ink)
            .frame(width: 32, height: 32)
            .background(Circle().fill(Color.paper))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var scoreText: some View {
        if let s = entry.displayScore {
            Text(String(format: "%.2f", s))
                .font(.body(size: 16, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(Color.ink)
        } else {
            Text("—")
                .font(.body(size: 16, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(Color.muted)
        }
    }

    private var accessibilityText: String {
        var parts: [String] = [entry.position.map { "Puesto \($0)" } ?? "Sin puesto"]
        if let name = entry.candidate.name { parts.append(name) }
        if entry.hasNotDriven {
            parts.append("Sin recorridos conducidos")
        } else if let s = entry.displayScore {
            parts.append("Nota \(String(format: "%.2f", s))")
        }
        parts.append("\(entry.attemptsCompleted) de \(entry.attemptsTotal) intentos")
        if entry.attemptId != nil { parts.append("Tocar para ver intento") }
        return parts.joined(separator: ", ")
    }
}
