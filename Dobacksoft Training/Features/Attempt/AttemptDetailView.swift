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
                    description: Text("No tenés acceso a este intento o no existe.")
                )
            case .loaded(let attempt):
                AttemptDetailContent(attempt: attempt)
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
        guard let token = auth.accessToken else { return }
        await viewModel.load(attemptId: attemptId, token: token)
    }
}

private struct AttemptDetailContent: View {
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
    }

    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.md.value) {
            // Hero score
            if let s = attempt.score {
                HStack(alignment: .firstTextBaseline, spacing: Theme.spacing.sm.value) {
                    Text(String(format: "%.2f", s))
                        .font(.display(size: 56, weight: .bold, italic: false, relativeTo: .largeTitle))
                        .foregroundStyle(scoreColor(s))
                    Text("/10")
                        .font(.cardTitle)
                        .foregroundStyle(Color.muted)
                    Spacer()
                    if let dq = attempt.dataQuality, !dq.isEmpty {
                        StatusBadge(text: dq, kind: dataQualityKind(dq))
                    }
                }
                Divider()
            }

            VStack(spacing: Theme.spacing.sm.value) {
                if let cand = attempt.candidate {
                    summaryRow(label: "Alumno", value: cand.name ?? "—")
                }
                if let route = attempt.route {
                    summaryRow(label: "Ruta", value: route.label ?? route.id ?? "—")
                }
                if let convId = attempt.convocatoriaId, !convId.isEmpty {
                    summaryRow(label: "Convocatoria", value: convId)
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.bodyText)
                .foregroundStyle(Color.muted)
            Spacer()
            Text(value)
                .font(.bodyEmphasis)
                .foregroundStyle(Color.ink)
        }
    }

    @ViewBuilder
    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            Text("Desglose")
                .font(.cardTitle)
                .foregroundStyle(Color.ink)
            VStack(spacing: 0) {
                ForEach(attempt.scoreBreakdown) { item in
                    HStack {
                        Text(item.family ?? "—")
                            .font(.bodyText)
                            .foregroundStyle(Color.inkSecondary)
                        Spacer()
                        Text("\(formatOrDash(item.obtained)) / \(formatOrDash(item.max))")
                            .font(.bodyEmphasis)
                            .foregroundStyle(Color.ink)
                    }
                    .padding(.vertical, Theme.spacing.sm.value)
                    if item.id != attempt.scoreBreakdown.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
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
                            if let ts = ev.timestamp {
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

    private func formatOrDash(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return String(format: "%.1f", v)
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0..<5:  return .danger
        case 5..<7:  return .warning
        case 7..<9:  return .brand
        default:     return .success
        }
    }

    private func dataQualityKind(_ value: String) -> BadgeKind {
        switch value.uppercased() {
        case "HIGH", "GOOD":  return .success
        case "MEDIUM", "OK":  return .warning
        case "LOW", "BAD":    return .danger
        default:              return .neutral
        }
    }
}
