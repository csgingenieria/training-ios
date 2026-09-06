import SwiftUI

private struct MatrixAttemptRoute: Hashable {
    let attemptId: String
}

private struct MatrixStudentRoute: Hashable {
    let studentId: String
}

// MARK: - ViewModel

@MainActor
@Observable
final class MatrixViewModel {
    enum State {
        case loading
        case loaded(MatrixResponseDTO)
        case empty
        case error(String)
    }

    var state: State = .loading

    func load(convocatoriaId: String, auth: AuthSession) async {
        state = .loading
        do {
            let response = try await auth.authorized { token in
                try await APIClient.shared.matrix(
                    convocatoriaId: convocatoriaId,
                    accessToken: token
                )
            }
            state = response.rows.isEmpty ? .empty : .loaded(response)
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

// MARK: - View

struct MatrixView: View {
    let convocatoriaId: String

    /// Nombre de la convocatoria, para el detalle del intento.
    var convocatoriaName: String?

    @Environment(AuthSession.self) private var auth
    @State private var viewModel = MatrixViewModel()

    private let cellMinWidth: CGFloat = 100
    private let nameColumnWidth: CGFloat = 160

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                VStack(spacing: Theme.spacing.md.value) {
                    ProgressView().tint(Color.brand)
                    Text("Cargando matriz…")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .pageBackground()
            case .empty:
                ContentUnavailableView(
                    "Matriz vacía",
                    systemImage: "tablecells",
                    description: Text("No hay candidatos registrados en esta convocatoria.")
                )
            case .loaded(let response):
                matrixContent(response)
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
        .navigationTitle("Matriz")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(for: MatrixAttemptRoute.self) { route in
            AttemptDetailView(attemptId: route.attemptId, convocatoriaName: convocatoriaName)
        }
        .navigationDestination(for: MatrixStudentRoute.self) { route in
            StudentProfileView(studentId: route.studentId)
        }
    }

    // MARK: - Matrix Content

    private func matrixContent(_ response: MatrixResponseDTO) -> some View {
        // Scroll bidireccional: el VStack contiene header + filas; el ScrollView
        // permite mover vertical y horizontal a la vez. `pinnedViews` mantiene el
        // header de circuitos visible mientras se scrollea verticalmente.
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(response.rows) { row in
                        dataRow(row, circuits: response.circuits)
                        Divider()
                    }
                } header: {
                    VStack(spacing: 0) {
                        matrixHeader(response)
                        headerRow(response.circuits)
                        Divider()
                    }
                    .background(Color.paperElevated)
                }
            }
        }
    }

    /// Contexto de la matriz.
    ///
    /// El ranking ya decía de qué convocatoria era y cuánta gente había; la
    /// matriz no, así que abierta desde un atajo no se sabía qué se miraba.
    @ViewBuilder
    private func matrixHeader(_ response: MatrixResponseDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.xs.value) {
            Text(response.convocatoria.name)
                .font(.cardTitle)
                .foregroundStyle(Color.ink)
            HStack(spacing: Theme.spacing.sm.value) {
                Text("\(response.rows.count) candidatos")
                Text("·")
                Text("\(response.circuits.filter { !$0.isSynthetic }.count) recorridos")
            }
            .font(.metaCaption)
            .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.spacing.base.value)
        .padding(.vertical, Theme.spacing.md.value)
    }

    // MARK: - Header Row

    private func headerRow(_ circuits: [MatrixCircuitDTO]) -> some View {
        HStack(spacing: 0) {
            Text("Candidato")
                .font(.body(size: 12, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(Color.muted)
                .frame(width: nameColumnWidth, alignment: .leading)
                .padding(.horizontal, Theme.spacing.md.value)
                .padding(.vertical, Theme.spacing.md.value)

            ForEach(circuits) { circuit in
                // Una columna sintética agrupa intentos sin recorrido
                // asignado. Pintar su identificador inventado —«U00»— la haría
                // pasar por un recorrido que no existe.
                Text(circuit.displayLabel)
                    .font(.body(size: 12, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(Color.muted)
                    .italic(circuit.isSynthetic)
                    .frame(minWidth: cellMinWidth, alignment: .center)
                    .padding(.horizontal, Theme.spacing.sm.value)
                    .padding(.vertical, Theme.spacing.md.value)
            }
        }
        .background(Color.paperElevated)
    }

    // MARK: - Data Row

    private func dataRow(_ row: MatrixRowDTO, circuits: [MatrixCircuitDTO]) -> some View {
        HStack(spacing: 0) {
            candidateCell(row.candidate)

            ForEach(circuits) { circuit in
                let cell = row.scores.first(where: { $0.circuitId == circuit.id })
                scoreCell(cell, candidateName: row.candidate.name, circuitLabel: circuit.displayLabel)
            }
        }
    }

    @ViewBuilder
    private func candidateCell(_ candidate: MatrixCandidateDTO) -> some View {
        // Tap en la columna nombre → perfil del alumno. Si el id está vacío,
        // queda como Text plano (sin tap).
        if !candidate.id.isEmpty {
            NavigationLink(value: MatrixStudentRoute(studentId: candidate.id)) {
                Text(candidate.name)
                    .font(.bodyText)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .frame(width: nameColumnWidth, alignment: .leading)
                    .padding(.horizontal, Theme.spacing.md.value)
                    .padding(.vertical, Theme.spacing.md.value)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(candidate.name)
            .accessibilityHint("Tocar para ver perfil del alumno")
        } else {
            Text(candidate.name)
                .font(.bodyText)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .frame(width: nameColumnWidth, alignment: .leading)
                .padding(.horizontal, Theme.spacing.md.value)
                .padding(.vertical, Theme.spacing.md.value)
        }
    }

    // MARK: - Score Cell

    @ViewBuilder
    private func scoreCell(
        _ cell: MatrixScoreDTO?,
        candidateName: String,
        circuitLabel: String
    ) -> some View {
        if let cell, let attemptId = cell.attemptId, !attemptId.isEmpty {
            NavigationLink(value: MatrixAttemptRoute(attemptId: attemptId)) {
                scoreCellContent(cell.score)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityCellLabel(candidateName, circuitLabel, cell.score))
            .accessibilityHint("Tocar para ver el intento")
        } else {
            scoreCellContent(cell?.score)
                .accessibilityLabel(accessibilityCellLabel(candidateName, circuitLabel, cell?.score))
        }
    }

    private func scoreCellContent(_ score: Double?) -> some View {
        HStack {
            Spacer(minLength: 0)
            if let s = score {
                Text(String(format: "%.1f", s))
                    .font(.body(size: 15, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(Color.ink)
            } else {
                Text("—")
                    .font(.bodyText)
                    .foregroundStyle(Color.muted)
            }
            Spacer(minLength: 0)
        }
        .frame(minWidth: cellMinWidth)
        .padding(.horizontal, Theme.spacing.sm.value)
        .padding(.vertical, Theme.spacing.md.value)
        .contentShape(Rectangle())
    }

    private func accessibilityCellLabel(_ candidate: String, _ circuit: String, _ score: Double?) -> String {
        if let s = score {
            return "\(candidate), \(circuit), nota \(String(format: "%.1f", s))"
        }
        return "\(candidate), \(circuit), sin nota"
    }

    // MARK: - Load

    private func load() async {
        await viewModel.load(convocatoriaId: convocatoriaId, auth: auth)
    }
}
