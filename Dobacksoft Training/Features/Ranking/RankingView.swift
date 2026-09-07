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
        case .attemptsDescending: return "Más recorridos completados"
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

    /// Nombre de la convocatoria, para que el detalle del intento no muestre
    /// un identificador crudo.
    var convocatoriaName: String?

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
                    // Identidad por índice: dos personas sin conducir y sin
                    // `candidate.id` comparten `entry.id` y SwiftUI las colapsa.
                    ForEach(Array(displayedEntries.enumerated()), id: \.offset) { idx, entry in
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
            AttemptDetailView(attemptId: route.attemptId, convocatoriaName: convocatoriaName)
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
                HStack(spacing: Theme.spacing.xs.value) {
                    Text(entry.candidate.name ?? "—")
                        .font(.bodyEmphasis)
                        .foregroundStyle(Color.ink)
                    // Numeración de competición: 1, 2, 2, 4. Sin decirlo, dos
                    // filas con el mismo puesto parecen un fallo de la app.
                    if entry.tied == true {
                        Text("empate")
                            .font(.metaCaption)
                            .foregroundStyle(Color.muted)
                    }
                }
                if let plaza = entry.candidate.plaza {
                    Text("Plaza \(plaza)")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                // De dónde sale la nota de esta fila.
                //
                // Sin esto el instructor lee «4,75» junto a alguien que ha
                // conducido cinco recorridos entre 8,5 y 10: el número es la
                // media sobre los diez exigidos, y los cinco no conducidos
                // computan cero. Enseñarlo a secas invita a concluir que
                // conduce mal, y esta es la pantalla desde la que se le llama.
                //
                // Descriptivo, nunca prescriptivo: «5 de 10 exigidos» es un
                // hecho; «le faltan 5» insinúa un deber y un resultado.
                if let composition = entry.composition, composition.hasPendingRoutes,
                   !composition.isGlobalBest {
                    Text(compositionLine(composition))
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
            Text(ScoreFormat.aggregate(s))
                .font(.body(size: 16, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(Color.ink)
        } else {
            Text("—")
                .font(.body(size: 16, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(Color.muted)
        }
    }

    /// «5 de 10 exigidos · media de lo conducido 9,50».
    ///
    /// La media va detrás y rotulada, no suelta: un 9,50 al lado de un 4,75 sin
    /// decir qué es cada uno se lee como una contradicción.
    private func compositionLine(_ composition: GradeComposition) -> String {
        var parts = ["\(composition.completedRequired) de \(composition.totalRequired) exigidos"]
        if let average = composition.scoreOfCompleted {
            parts.append("media de lo conducido \(ScoreFormat.aggregate(average))")
        }
        return parts.joined(separator: " · ")
    }

    private var accessibilityText: String {
        var parts: [String] = [entry.position.map { "Puesto \($0)" } ?? "Sin puesto"]
        if let name = entry.candidate.name { parts.append(name) }
        if entry.hasNotDriven {
            parts.append("Sin recorridos conducidos")
        } else if let s = entry.displayScore {
            parts.append("Nota \(ScoreFormat.aggregate(s))")
        }
        parts.append("\(entry.attemptsTotal) intentos")
        if let composition = entry.composition, composition.hasPendingRoutes,
           !composition.isGlobalBest {
            parts.append(compositionLine(composition))
        }
        if entry.attemptId != nil { parts.append("Tocar para ver intento") }
        return parts.joined(separator: ", ")
    }
}
