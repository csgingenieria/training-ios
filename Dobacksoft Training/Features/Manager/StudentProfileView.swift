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
        } catch let error as APIError where error.notFoundReason != nil {
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
                    Text("Cargando el aspirante…")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .pageBackground()
            case .notFound:
                ContentUnavailableView(
                    "Aspirante no encontrado",
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
        .navigationTitle("Aspirante")
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
                    Text("Este aspirante todavía no tiene intentos cerrados.")
                        .font(.bodyText)
                        .foregroundStyle(Color.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                }
            }
            .readableWidth()
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
            StatusBadge(text: StatusVocabulary.role(user.role), kind: .brand)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                let estado = StatusVocabulary.enrolment(standing.status)
                StatusBadge(text: estado.label, kind: estado.kind)
            }

            // Se apilan con los tamaños de accesibilidad.
            //
            // Tres métricas en una fila con divisores de 28 pt de alto: con la
            // letra grande, «Nota pendiente de confirmación» se parte en cinco
            // o seis líneas dentro de una columna estrecha, y el divisor fijo
            // se queda colgando a media altura del texto.
            //
            // `AnyLayout` cambia la disposición sin recrear las vistas, así que
            // no se pierde nada al girar el ajuste.
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.spacing.md.value))
                : AnyLayout(HStackLayout(spacing: Theme.spacing.lg.value))
            layout {
                metric(label: "Puesto", value: "\(standing.position)/\(standing.totalCandidates)")
                // Sin altura fija: en vertical un divisor de 28 pt es una raya
                // suelta, y en horizontal `Divider()` ya se ajusta a la fila.
                Divider()
                metric(label: "Nota", value: ScoreFormat.aggregate(standing.score))
                Divider()
                metric(label: "Intentos", value: "\(standing.attemptsTotal)")
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            }

            // De qué está hecha esa nota.
            //
            // El DTO traía la composición desde que el contrato la envía y esta
            // pantalla no la usaba: el instructor abría el perfil de alguien,
            // leía «0,85» y no tenía nada que explicase el número. Es la misma
            // laguna que tenía el ranking, y es peor aquí, porque esta es la
            // pantalla desde la que se llama a un aspirante.
            //
            // Descriptivo, nunca prescriptivo: «1 de 10 exigidos» es un hecho.
            if let composition = standing.composition,
               composition.hasPendingRoutes, !composition.isGlobalBest {
                Text(compositionLine(composition))
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: standing))
    }

    /// «1 de 10 exigidos · media de lo conducido 8,50».
    ///
    /// La media va rotulada y detrás: un 8,50 al lado de un 0,85 sin decir qué
    /// es cada uno se lee como una contradicción.
    private func compositionLine(_ composition: GradeComposition) -> String {
        var parts = ["\(composition.completedRequired) de \(composition.totalRequired) exigidos"]
        if let average = composition.scoreOfCompleted {
            parts.append("media de lo conducido \(ScoreFormat.aggregate(average))")
        }
        if let explanation = composition.explanation {
            parts.append(explanation)
        }
        return parts.joined(separator: " · ")
    }

    private func accessibilityLabel(for standing: ProfileStandingDTO) -> String {
        var parts = [
            standing.name,
            "puesto \(standing.position) de \(standing.totalCandidates)",
            "nota \(ScoreFormat.aggregate(standing.score))",
            "\(standing.attemptsTotal) intentos",
        ]
        if let composition = standing.composition,
           composition.hasPendingRoutes, !composition.isGlobalBest {
            parts.append(compositionLine(composition))
        }
        return parts.joined(separator: ", ")
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

}
