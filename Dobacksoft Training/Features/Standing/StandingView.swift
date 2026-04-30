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

    func load(convocatoriaId: String, token: String) async {
        state = .loading
        do {
            let standing = try await APIClient.shared.standing(
                convocatoriaId: convocatoriaId,
                accessToken: token
            )
            state = .loaded(standing)
        } catch APIError.notFound {
            state = .notFound
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

struct StandingView: View {
    let convocatoriaId: String
    @Environment(AuthSession.self) private var auth
    @State private var viewModel = StandingViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Cargando posición…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .notFound:
                ContentUnavailableView(
                    "Sin inscripción",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("No tenés una inscripción activa en esta convocatoria.")
                )
            case .loaded(let standing):
                StandingCard(standing: standing)
                    .padding()
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
        .navigationTitle("Mi posición")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let token = auth.accessToken else { return }
        await viewModel.load(convocatoriaId: convocatoriaId, token: token)
    }
}

struct StandingCard: View {
    let standing: StandingDTO

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("Puesto")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(standing.position)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                Text("de \(standing.totalCandidates)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                StandingMetric(title: "Nota", value: String(format: "%.2f", standing.score))
                StandingMetric(title: "Plazas", value: "\(standing.plazas)")
                StandingMetric(
                    title: "Intentos",
                    value: "\(standing.attemptsCompleted)/\(standing.attemptsTotal)"
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Estado: \(standing.status)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("La asignación de plaza la decide CMadrid al cierre de la convocatoria.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct StandingMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.semibold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Tab del STUDENT en el dashboard: carga su primera convocatoria activa
/// y muestra su standing directo. Si tiene varias, sigue funcionando con la más reciente.
struct MyStandingTabView: View {
    @Environment(AuthSession.self) private var auth
    @State private var convocatorias: [ConvocatoriaSummaryDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Cargando…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle.fill",
                    description: Text(errorMessage)
                )
            } else if convocatorias.isEmpty {
                ContentUnavailableView(
                    "Sin convocatorias",
                    systemImage: "tray.fill",
                    description: Text("Todavía no estás inscripto en ninguna convocatoria.")
                )
            } else if let first = convocatorias.first {
                StandingView(convocatoriaId: first.id)
            }
        }
        .navigationTitle("Mi posición")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = auth.accessToken else { return }
        do {
            convocatorias = try await APIClient.shared.myConvocatorias(accessToken: token)
        } catch let err as APIError {
            errorMessage = err.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
