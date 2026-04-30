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

    func load(token: String, isStudent: Bool) async {
        state = .loading
        do {
            let items: [ConvocatoriaSummaryDTO]
            if isStudent {
                items = try await APIClient.shared.myConvocatorias(accessToken: token)
            } else {
                items = try await APIClient.shared.convocatorias(accessToken: token)
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

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Cargando…").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                ContentUnavailableView(
                    "Sin convocatorias",
                    systemImage: "tray.fill",
                    description: Text("No tenés convocatorias visibles para tu rol.")
                )
            case .loaded(let items):
                List(items) { conv in
                    NavigationLink(value: conv) {
                        ConvocatoriaRow(conv: conv)
                    }
                }
                .navigationDestination(for: ConvocatoriaSummaryDTO.self) { conv in
                    ConvocatoriaDetailView(convocatoria: conv)
                }
            case .error(let msg):
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(msg)
                } actions: {
                    Button("Reintentar") { Task { await load() } }
                }
            }
        }
        .navigationTitle("Convocatorias")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let token = auth.accessToken else { return }
        await viewModel.load(token: token, isStudent: auth.user?.isStudent ?? false)
    }
}

struct ConvocatoriaRow: View {
    let conv: ConvocatoriaSummaryDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(conv.name).font(.headline)
            if let descr = conv.description, !descr.isEmpty {
                Text(descr).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            HStack(spacing: 12) {
                Label("\(conv.totalCandidates)", systemImage: "person.3")
                    .font(.caption).foregroundStyle(.secondary)
                Label("\(conv.plazas) plazas", systemImage: "ticket")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let status = conv.status {
                    Text(status)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.thinMaterial, in: Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ConvocatoriasListView()
            .environment(AuthSession.previewAuthenticated)
    }
}
