import SwiftUI

private struct WebfletAlertRoute: Hashable {
    let attemptId: String
}

@MainActor
@Observable
final class WebfletAlertsViewModel {
    enum State {
        case loading
        case loaded(WebfletAlertsResponseDTO)
        case empty
        case error(String)
    }

    var state: State = .loading

    func load(auth: AuthSession) async {
        state = .loading
        do {
            let response = try await auth.authorized { token in
                try await APIClient.shared.webfletAlerts(accessToken: token)
            }
            state = response.items.isEmpty ? .empty : .loaded(response)
        } catch let err as APIError {
            state = .error(err.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

/// Lista de alertas operativas de enriquecimiento Webfleet (MANAGER/ADMIN).
/// Backend rate-limit: 30/min. No hay polling automático — solo refresh
/// manual (pull-to-refresh) o re-entrada a la vista.
struct WebfletAlertsView: View {
    @Environment(AuthSession.self) private var auth
    @State private var viewModel = WebfletAlertsViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                VStack(spacing: Theme.spacing.md.value) {
                    ProgressView().tint(Color.brand)
                    Text("Cargando alertas…")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .pageBackground()
            case .empty:
                ContentUnavailableView(
                    "Sin alertas",
                    systemImage: "bell.slash",
                    description: Text("No hay incidencias de enriquecimiento Webfleet pendientes.")
                )
            case .loaded(let response):
                loadedList(response)
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
        .navigationTitle("Alertas Webfleet")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(for: WebfletAlertRoute.self) { route in
            AttemptDetailView(attemptId: route.attemptId)
        }
    }

    @ViewBuilder
    private func loadedList(_ response: WebfletAlertsResponseDTO) -> some View {
        ScrollView {
            VStack(spacing: Theme.spacing.md.value) {
                summaryHeader(response)
                LazyVStack(spacing: Theme.spacing.md.value) {
                    ForEach(response.items) { alert in
                        NavigationLink(value: WebfletAlertRoute(attemptId: alert.attemptId)) {
                            WebfletAlertRow(alert: alert)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Theme.spacing.base.value)
            .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
    }

    @ViewBuilder
    private func summaryHeader(_ response: WebfletAlertsResponseDTO) -> some View {
        let errors = response.items.filter { $0.severity == .error }.count
        let warnings = response.items.filter { $0.severity == .warning }.count

        HStack(spacing: Theme.spacing.lg.value) {
            metric(label: "Total", value: "\(response.count)", kind: .neutral)
            metric(label: "Errores", value: "\(errors)", kind: .danger)
            metric(label: "Advertencias", value: "\(warnings)", kind: .warning)
            Spacer()
        }
        .cardStyle()
    }

    private func metric(label: String, value: String, kind: BadgeKind) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.body(size: 22, weight: .semibold, relativeTo: .title2))
                .foregroundStyle(kind.foreground)
            Text(label)
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
        }
    }

    private func load() async {
        await viewModel.load(auth: auth)
    }
}

private struct WebfletAlertRow: View {
    let alert: WebfletAlertDTO

    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacing.md.value) {
            severityIcon
            VStack(alignment: .leading, spacing: Theme.spacing.xs.value) {
                HStack(spacing: Theme.spacing.sm.value) {
                    Text(alert.type)
                        .font(.cardTitle)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Spacer()
                    StatusBadge(text: severityLabel, kind: severityKind)
                }

                if let student = alert.studentName, !student.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text(student)
                            .font(.metaCaption)
                    }
                    .foregroundStyle(Color.muted)
                }

                if let message = alert.message, !message.isEmpty {
                    Text(message)
                        .font(.metaCaption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    if let ts = APIDate.shortDateTime(alert.timestamp) {
                        Text(ts)
                            .font(.metaCaption)
                            .foregroundStyle(Color.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.muted)
                        .accessibilityHidden(true)
                }
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Tocar para ver el intento")
    }

    private var severityIcon: some View {
        Image(systemName: alert.severity == .error ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
            .font(.body(size: 18, weight: .semibold))
            .foregroundStyle(severityKind.foreground)
            .frame(width: 28, alignment: .top)
            .accessibilityHidden(true)
    }

    private var severityKind: BadgeKind {
        switch alert.severity {
        case .error:   return .danger
        case .warning: return .warning
        case .unknown: return .neutral
        }
    }

    private var severityLabel: String {
        switch alert.severity {
        case .error:   return "ERROR"
        case .warning: return "AVISO"
        case .unknown: return "—"
        }
    }

    private var accessibilityText: String {
        var parts: [String] = [severityLabel, alert.type]
        if let s = alert.studentName { parts.append(s) }
        if let m = alert.message { parts.append(m) }
        return parts.joined(separator: ", ")
    }
}
