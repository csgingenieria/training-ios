import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var auth

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
        .task {
            await auth.restoreFromKeychain()
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
