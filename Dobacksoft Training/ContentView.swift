import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(\.scenePhase) private var scenePhase

    /// Vive aquí, y no en el dashboard, porque tiene que sobrevivir a un
    /// cambio de size class: es lo único que sabe que la persona se fue.
    @State private var ticker = RefreshTicker()

    var body: some View {
        Group {
            if !auth.hasRestoredSession {
                LaunchView()
            } else if auth.isAuthenticated {
                DashboardView()
            } else {
                LoginView()
            }
        }
        .environment(ticker)
        .task {
            await auth.restoreFromKeychain()
        }
        .onChange(of: scenePhase) { _, phase in
            ticker.scenePhaseChanged(to: phase)
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(SessionCopy.restoring)
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RootView()
        .environment(AuthSession.previewAuthenticated)
}
