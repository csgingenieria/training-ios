import SwiftUI

@MainActor
@Observable
final class AttemptDetailViewModel {
    enum State {
        case loading
        case loaded(AttemptDetailDTO)
        case notFound
        case error(String)
    }

    var state: State = .loading

    func load(attemptId: String, token: String) async {
        state = .loading
        do {
            let attempt = try await APIClient.shared.attempt(id: attemptId, accessToken: token)
            state = .loaded(attempt)
        } catch APIError.notFound {
            state = .notFound
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

struct AttemptDetailView: View {
    let attemptId: String
    @Environment(AuthSession.self) private var auth
    @State private var viewModel = AttemptDetailViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Cargando intento…")
            case .notFound:
                ContentUnavailableView(
                    "Intento no encontrado",
                    systemImage: "questionmark.folder",
                    description: Text("No tenés acceso a este intento o no existe.")
                )
            case .loaded(let attempt):
                AttemptForm(attempt: attempt)
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
        .navigationTitle("Intento")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard let token = auth.accessToken else { return }
        await viewModel.load(attemptId: attemptId, token: token)
    }
}

struct AttemptForm: View {
    let attempt: AttemptDetailDTO

    var body: some View {
        Form {
            Section("Resumen") {
                if let cand = attempt.candidate {
                    LabeledContent("Alumno", value: cand.name ?? "—")
                }
                if let route = attempt.route {
                    LabeledContent("Ruta", value: route.label ?? route.id ?? "—")
                }
                if let s = attempt.score {
                    LabeledContent("Nota", value: String(format: "%.2f", s))
                }
                if let dq = attempt.dataQuality {
                    LabeledContent("Calidad de datos", value: dq)
                }
            }

            if !attempt.scoreBreakdown.isEmpty {
                Section("Desglose") {
                    ForEach(attempt.scoreBreakdown) { item in
                        HStack {
                            Text(item.family ?? "—")
                            Spacer()
                            Text("\(formatOrDash(item.obtained)) / \(formatOrDash(item.max))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !attempt.events.isEmpty {
                Section("Eventos") {
                    ForEach(attempt.events) { ev in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(ev.type ?? "—").font(.body.weight(.medium))
                                Spacer()
                                if let ts = ev.timestamp {
                                    Text(ts).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if let descr = ev.description {
                                Text(descr).font(.caption)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func formatOrDash(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return String(format: "%.1f", v)
    }
}
