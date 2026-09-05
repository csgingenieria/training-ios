import SwiftUI

@MainActor
@Observable
final class ConvocatoriasListViewModel {
    enum State {
        case loading
        case loaded([ConvocatoriaSummaryDTO])
        case empty
        case error(String)
    }

    var state: State = .loading

    func load(auth: AuthSession, isStudent: Bool) async {
        state = .loading
        do {
            let items = try await auth.authorized { token in
                isStudent
                    ? try await APIClient.shared.myConvocatorias(accessToken: token)
                    : try await APIClient.shared.convocatorias(accessToken: token)
            }
            state = items.isEmpty ? .empty : .loaded(items)
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

struct ConvocatoriasListView: View {
    @Environment(AuthSession.self) private var auth
    @State private var viewModel = ConvocatoriasListViewModel()
    @State private var searchText = ""

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                loadingView
            case .empty:
                ContentUnavailableView(
                    "Sin convocatorias",
                    systemImage: "tray.fill",
                    description: Text("No hay convocatorias visibles para su perfil.")
                )
            case .loaded(let items):
                let filtered = filter(items)
                if filtered.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    loadedList(filtered)
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
        .navigationTitle("Convocatorias")
        .searchable(text: $searchText, prompt: "Buscar convocatoria")
        .task { await load() }
        .refreshable { await load() }
    }

    private func filter(_ items: [ConvocatoriaSummaryDTO]) -> [ConvocatoriaSummaryDTO] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.name.lowercased().contains(query) ||
            ($0.description?.lowercased().contains(query) ?? false)
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: Theme.spacing.md.value) {
            ProgressView()
                .tint(Color.brand)
            Text("Cargando convocatorias…")
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pageBackground()
    }

    @ViewBuilder
    private func loadedList(_ items: [ConvocatoriaSummaryDTO]) -> some View {
        ScrollView {
            LazyVStack(spacing: Theme.spacing.md.value) {
                ForEach(items) { conv in
                    NavigationLink(value: conv) {
                        ConvocatoriaRow(conv: conv)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
        .navigationDestination(for: ConvocatoriaSummaryDTO.self) { conv in
            ConvocatoriaDetailView(convocatoria: conv)
        }
    }

    private func load() async {
        await viewModel.load(auth: auth, isStudent: auth.user?.isStudent ?? false)
    }
}

struct ConvocatoriaRow: View {
    let conv: ConvocatoriaSummaryDTO

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            HStack(alignment: .top, spacing: Theme.spacing.sm.value) {
                Text(conv.name)
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let status = conv.status {
                    StatusBadge(text: status, kind: badgeKind(for: status))
                }
            }

            if let descr = conv.description, !descr.isEmpty {
                Text(descr)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .lineLimit(2)
            }

            HStack(spacing: Theme.spacing.base.value) {
                metric(icon: "person.3.fill", text: "\(conv.totalCandidates) candidatos")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.muted)
                    .accessibilityHidden(true)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Tocar para ver detalle")
    }

    private func metric(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.metaCaption)
        }
        .foregroundStyle(Color.muted)
    }

    private func badgeKind(for status: String) -> BadgeKind {
        switch status.uppercased() {
        case "OPEN", "ACTIVE", "ACTIVA", "EN CURSO": return .success
        case "CLOSED", "CERRADA":                    return .neutral
        case "DRAFT", "BORRADOR":                    return .warning
        default:                                     return .brand
        }
    }

    private var accessibilitySummary: String {
        var parts: [String] = [conv.name]
        if let status = conv.status { parts.append(status) }
        parts.append("\(conv.totalCandidates) candidatos")
        return parts.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack {
        ConvocatoriasListView()
            .environment(AuthSession.previewAuthenticated)
    }
}
