import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(\.scenePhase) private var scenePhase

    /// Vive aquí, y no en el dashboard, porque tiene que sobrevivir a un
    /// cambio de size class: es lo único que sabe que la persona se fue.
    @State private var ticker = RefreshTicker()

    /// Y esto vive aquí porque un arranque en frío desde el widget entrega la
    /// URL mientras todavía está la pantalla de carga: el dashboard, que es
    /// quien puede atenderla, no existe todavía.
    @State private var deepLinks = DeepLinkInbox()

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
        .environment(deepLinks)
        .task {
            await auth.restoreFromKeychain()
        }
        .onOpenURL { url in
            deepLinks.receive(url)
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
