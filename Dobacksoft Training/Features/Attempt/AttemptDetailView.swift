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

    func load(attemptId: String, auth: AuthSession) async {
        state = .loading
        do {
            let attempt = try await auth.authorized { token in
                try await APIClient.shared.attempt(id: attemptId, accessToken: token)
            }
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

    /// Nombre de la convocatoria del intento. El contrato solo envía el
    /// identificador, así que lo aporta quien navega hasta aquí y lo conoce.
    var convocatoriaName: String?

    @Environment(AuthSession.self) private var auth
    @State private var viewModel = AttemptDetailViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                VStack(spacing: Theme.spacing.md.value) {
                    ProgressView().tint(Color.brand)
                    Text("Cargando intento…")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .pageBackground()
            case .notFound:
                ContentUnavailableView(
                    "Intento no encontrado",
                    systemImage: "questionmark.folder",
                    description: Text("No dispone de acceso a este intento, o el intento no existe.")
                )
            case .loaded(let attempt):
                AttemptDetailContent(convocatoriaName: convocatoriaName, attempt: attempt)
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
        .navigationTitle("Intento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .loaded(let attempt) = viewModel.state {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareText(attempt)) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.brand)
                    }
                    .accessibilityLabel("Compartir resumen del intento")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func shareText(_ attempt: AttemptDetailDTO) -> String {
        var lines: [String] = ["Intento Training · CMadrid"]
        if let candName = attempt.candidate?.name { lines.append("Alumno: \(candName)") }
        if let routeLabel = attempt.route?.label ?? attempt.route?.id {
            lines.append("Ruta: \(routeLabel)")
        }
        if let s = attempt.score {
            lines.append("Nota: \(String(format: "%.2f", s))/10")
        }
        if let dq = attempt.dataQuality {
            lines.append("Calidad: \(dq)")
        }
        return lines.joined(separator: "\n")
    }

    private func load() async {
        await viewModel.load(attemptId: attemptId, auth: auth)
    }
}

private struct AttemptStudentRoute: Hashable {
    let studentId: String
}

private struct AttemptDetailContent: View {
    @Environment(AuthSession.self) private var auth

    /// Nombre de la convocatoria, resuelto por quien navega hasta aquí. El
    /// contrato solo envía el identificador.
    var convocatoriaName: String?

    let attempt: AttemptDetailDTO

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing.lg.value) {
                summaryCard
                if !attempt.scoreBreakdown.isEmpty {
                    breakdownCard
                }
                if !attempt.events.isEmpty {
                    eventsCard
                }
            }
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
        .navigationDestination(for: AttemptStudentRoute.self) { route in
            StudentProfileView(studentId: route.studentId)
        }
    }

    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.md.value) {
            // Hero score
            if let s = attempt.score {
                HStack(alignment: .firstTextBaseline, spacing: Theme.spacing.sm.value) {
                    Text(String(format: "%.2f", s))
                        .font(.display(size: 56, weight: .bold, italic: false, relativeTo: .largeTitle))
                        .foregroundStyle(Color.ink)
                    Text("/10")
                        .font(.cardTitle)
                        .foregroundStyle(Color.muted)
                    Spacer()
                    if let quality = attempt.quality {
                        StatusBadge(text: quality.label, kind: quality.badgeKind)
                    }
                }
                Divider()
            }

            VStack(spacing: Theme.spacing.sm.value) {
                if let cand = attempt.candidate {
                    // Desde el ranking y la matriz se llega al perfil del
                    // aspirante; entrando por una alerta de Webfleet no había
                    // salida hacia él.
                    if let candidateId = cand.id, !candidateId.isEmpty, auth.user?.isAdminLike == true {
                        NavigationLink(value: AttemptStudentRoute(studentId: candidateId)) {
                            summaryRow(
                                label: "Alumno",
                                value: cand.name ?? "—",
                                showsDisclosure: true
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        summaryRow(label: "Alumno", value: cand.name ?? "—")
                    }
                }
                if let route = attempt.route {
                    summaryRow(label: "Ruta", value: route.label ?? route.id ?? "—")
                }
                // El contrato solo trae el identificador; el nombre se resuelve
                // contra la lista que la app ya tiene cargada. Si no está, no se
                // pinta un UUID al usuario.
                if let convocatoriaName {
                    summaryRow(label: "Convocatoria", value: convocatoriaName)
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private func summaryRow(
        label: String,
        value: String,
        showsDisclosure: Bool = false
    ) -> some View {
        HStack {
            Text(label)
                .font(.bodyText)
                .foregroundStyle(Color.muted)
            Spacer()
            Text(value)
                .font(.bodyEmphasis)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.trailing)
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.muted)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }

    /// Desglose de la nota por componente.
    ///
    /// Las filas se identifican por índice: `family` es una etiqueta de display
    /// y dos filas del mismo componente pueden compartirla.
    @ViewBuilder
    private var breakdownCard: some View {
        // Un intento de entrada manual llega sin desglose. Mejor no enseñar la
        // tarjeta que enseñar un encabezado sobre nada.
        if !attempt.scoreBreakdown.isEmpty {
            VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
                Text("Desglose")
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                VStack(spacing: 0) {
                    ForEach(Array(attempt.scoreBreakdown.enumerated()), id: \.offset) { index, item in
                        breakdownRow(item)
                        if index < attempt.scoreBreakdown.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    @ViewBuilder
    private func breakdownRow(_ item: AttemptScoreFamilyDTO) -> some View {
        HStack {
            Text(item.family ?? "—")
                .font(.bodyText)
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            switch item.presentation {
            case let .measured(obtained, max):
                Text("\(formatScore(obtained)) / \(formatScore(max))")
                    .font(.bodyEmphasis)
                    .foregroundStyle(Color.ink)
            case .notMeasured, .missingData:
                // Sin números: «— / 0» se leía como un cero que el aspirante
                // no sacó. El backend sabe el motivo exacto, pero todavía no lo
                // envía, así que la app dice lo que sabe y nada más.
                Text(item.presentation.label)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
        }
        .padding(.vertical, Theme.spacing.sm.value)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            Text("Eventos")
                .font(.cardTitle)
                .foregroundStyle(Color.ink)
            VStack(spacing: 0) {
                ForEach(attempt.events) { ev in
                    VStack(alignment: .leading, spacing: Theme.spacing.xs.value) {
                        HStack {
                            Text(ev.type ?? "—")
                                .font(.bodyEmphasis)
                                .foregroundStyle(Color.ink)
                            Spacer()
                            if let ts = APIDate.shortDateTime(ev.timestamp) {
                                Text(ts)
                                    .font(.metaCaption)
                                    .foregroundStyle(Color.muted)
                            }
                        }
                        if let descr = ev.description {
                            Text(descr)
                                .font(.metaCaption)
                                .foregroundStyle(Color.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        // De dónde salió y con qué intensidad lo registró el
                        // sensor. Sin esto, todos los eventos se leen igual de
                        // graves y sin procedencia.
                        HStack(spacing: Theme.spacing.sm.value) {
                            if let source = ev.sourceLabel {
                                Label(source, systemImage: "dot.radiowaves.left.and.right")
                                    .font(.metaCaption)
                                    .foregroundStyle(Color.muted)
                            }
                            if let severity = ev.sensorSeverity {
                                Text("Intensidad \(severity.rawValue.lowercased())")
                                    .font(.metaCaption)
                                    .foregroundStyle(Color.muted)
                            }
                        }
                    }
                    .padding(.vertical, Theme.spacing.sm.value)
                    if ev.id != attempt.events.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Dos decimales: el peso efectivo que el backend fija por recorrido los
    /// usa, y redondear a uno mostraba un máximo que no era el configurado.
    private func formatScore(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

}
