import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var auth

    var body: some View {
        Group {
            if auth.isAuthenticated {
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

#Preview {
    RootView()
        .environment(AuthSession.previewAuthenticated)
}
