import SwiftUI

private struct StudentAttemptDetailRoute: Hashable {
    let attemptId: String
}

@MainActor
@Observable
final class StudentProfileViewModel {
    enum State {
        case loading
        case loaded(StudentProfileDTO)
        case notFound
        case error(String)
    }

    var state: State = .loading

    func load(studentId: String, auth: AuthSession) async {
        state = .loading
        do {
            let profile = try await auth.authorized { token in
                try await APIClient.shared.studentProfile(
                    studentId: studentId,
                    accessToken: token
                )
            }
            state = .loaded(profile)
        } catch APIError.notFound {
            // Defense in depth del backend: 404 también si es otra org o no
            // tiene rol STUDENT. No leakeamos cuál es la razón.
            state = .notFound
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

/// Perfil de alumno visto por MANAGER/ADMIN. Carga
/// `GET /api/v1/students/<id>/profile` y muestra:
///   - datos del usuario
///   - standings por convocatoria
///   - lista de intentos cerrados
struct StudentProfileView: View {
    let studentId: String
    @Environment(AuthSession.self) private var auth
    @State private var viewModel = StudentProfileViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                VStack(spacing: Theme.spacing.md.value) {
                    ProgressView().tint(Color.brand)
                    Text("Cargando alumno…")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .pageBackground()
            case .notFound:
                ContentUnavailableView(
                    "Alumno no encontrado",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("No dispone de acceso a este aspirante, o el aspirante no existe.")
                )
            case .loaded(let profile):
                content(profile)
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
        .navigationTitle("Alumno")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(for: StudentAttemptDetailRoute.self) { route in
            AttemptDetailView(attemptId: route.attemptId)
        }
    }

    @ViewBuilder
    private func content(_ profile: StudentProfileDTO) -> some View {
        ScrollView {
            VStack(spacing: Theme.spacing.lg.value) {
                userCard(profile.user)
                if !profile.standings.isEmpty {
                    standingsSection(profile.standings)
                }
                if !profile.attempts.isEmpty {
                    attemptsSection(profile.attempts)
                }
                if profile.standings.isEmpty && profile.attempts.isEmpty {
                    Text("Este alumno todavía no tiene intentos cerrados.")
                        .font(.bodyText)
                        .foregroundStyle(Color.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                }
            }
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
    }

    @ViewBuilder
    private func userCard(_ user: UserDTO) -> some View {
        HStack(spacing: Theme.spacing.base.value) {
            ZStack {
                Circle().fill(Color.brandTint)
                Text(user.name.prefix(1).uppercased())
                    .font(.display(size: 26, weight: .bold, italic: true, relativeTo: .title))
                    .foregroundStyle(Color.brand)
            }
            .frame(width: 56, height: 56)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                Text(user.email)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
            Spacer()
            StatusBadge(text: user.role.uppercased(), kind: .brand)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func standingsSection(_ standings: [ProfileStandingDTO]) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            Text("Posición en convocatorias")
                .font(.sectionTitle)
                .foregroundStyle(Color.ink)
                .padding(.horizontal, Theme.spacing.xs.value)

            VStack(spacing: Theme.spacing.md.value) {
                ForEach(standings) { st in
                    ProfileStandingRow(standing: st)
                }
            }
        }
    }

    @ViewBuilder
    private func attemptsSection(_ attempts: [AttemptSummaryDTO]) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            HStack {
                Text("Intentos cerrados")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("\(attempts.count)")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
            .padding(.horizontal, Theme.spacing.xs.value)

            VStack(spacing: 0) {
                ForEach(attempts) { attempt in
                    NavigationLink(value: StudentAttemptDetailRoute(attemptId: attempt.id)) {
                        AttemptSummaryRow(attempt: attempt)
                    }
                    .buttonStyle(.plain)
                    if attempt.id != attempts.last?.id {
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
    }

    private func load() async {
        await viewModel.load(studentId: studentId, auth: auth)
    }
}

private struct ProfileStandingRow: View {
    let standing: ProfileStandingDTO

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(standing.name)
                        .font(.cardTitle)
                        .foregroundStyle(Color.ink)
                        .lineLimit(2)
                    Text("Convocatoria")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                Spacer()
                StatusBadge(text: standing.status, kind: statusKind(standing.status))
            }

            HStack(spacing: Theme.spacing.lg.value) {
                metric(label: "Puesto", value: "\(standing.position)/\(standing.totalCandidates)")
                Divider().frame(height: 28)
                metric(label: "Nota", value: String(format: "%.2f", standing.score))
                Divider().frame(height: 28)
                metric(label: "Intentos", value: "\(standing.attemptsCompleted)/\(standing.attemptsTotal)")
                Spacer()
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(standing.name), puesto \(standing.position) de \(standing.totalCandidates), " +
            "nota \(String(format: "%.2f", standing.score)), " +
            "\(standing.attemptsCompleted) de \(standing.attemptsTotal) intentos"
        )
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.body(size: 16, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(Color.ink)
            Text(label)
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
        }
    }

    private func statusKind(_ status: String) -> BadgeKind {
        switch status.uppercased() {
        case "ACTIVE", "ACTIVA":              return .success
        case "WITHDRAWN", "INVALIDATED", "BAJA": return .danger
        default:                              return .neutral
        }
    }
}
