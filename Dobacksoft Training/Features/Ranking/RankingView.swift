import SwiftUI

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

    func load(convocatoriaId: String, token: String) async {
        state = .loading
        do {
            let response = try await APIClient.shared.ranking(
                convocatoriaId: convocatoriaId,
                accessToken: token
            )
            state = response.entries.isEmpty ? .empty : .loaded(response)
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

struct RankingView: View {
    let convocatoriaId: String
    @Environment(AuthSession.self) private var auth
    @State private var viewModel = RankingViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Cargando ranking…")
            case .empty:
                ContentUnavailableView(
                    "Ranking vacío",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Todavía no hay entradas en esta convocatoria.")
                )
            case .loaded(let response):
                List {
                    Section {
                        ForEach(response.entries) { entry in
                            RankingEntryRow(entry: entry, plazas: response.convocatoria.plazas)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(response.convocatoria.name).font(.headline)
                            Text("\(response.entries.count) candidatos · \(response.convocatoria.plazas) plazas")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .textCase(nil)
                    }
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
        .navigationTitle("Ranking")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let token = auth.accessToken else { return }
        await viewModel.load(convocatoriaId: convocatoriaId, token: token)
    }
}

struct RankingEntryRow: View {
    let entry: RankingEntryDTO
    let plazas: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(entry.position)")
                .font(.title3.weight(.semibold))
                .frame(width: 36, alignment: .center)
                .foregroundStyle(entry.position <= plazas ? .primary : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.candidate.name ?? "—").font(.body)
                if let plaza = entry.candidate.plaza {
                    Text("Plaza \(plaza)").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let s = entry.score {
                    Text(String(format: "%.2f", s)).font(.body.weight(.semibold))
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
                Text("\(entry.attemptsCompleted)/\(entry.attemptsTotal)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
