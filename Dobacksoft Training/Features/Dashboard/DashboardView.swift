import SwiftUI

struct DashboardView: View {
    @Environment(AuthSession.self) private var auth

    var body: some View {
        TabView {
            Tab("Convocatorias", systemImage: "list.bullet.rectangle") {
                NavigationStack {
                    ConvocatoriasListView()
                }
            }

            if auth.user?.isStudent == true {
                Tab("Mi posición", systemImage: "trophy.fill") {
                    NavigationStack {
                        MyStandingTabView()
                    }
                }
            }

            Tab("Perfil", systemImage: "person.crop.circle") {
                NavigationStack {
                    ProfileView()
                }
            }
        }
    }
}

struct ProfileView: View {
    @Environment(AuthSession.self) private var auth

    var body: some View {
        Form {
            if let user = auth.user {
                Section("Mi cuenta") {
                    LabeledContent("Nombre", value: user.name)
                    LabeledContent("Email", value: user.email)
                    LabeledContent("Rol", value: user.role)
                    if let orgId = user.organizationId {
                        LabeledContent("Organización", value: orgId)
                    }
                }
            }

            Section("API") {
                LabeledContent("Base URL", value: AppEnvironment.baseURL.absoluteString)
                LabeledContent("Cliente", value: AppEnvironment.clientVersion)
            }

            Section {
                Button("Cerrar sesión", role: .destructive) {
                    Task { await auth.logout() }
                }
            }
        }
        .navigationTitle("Perfil")
    }
}

#Preview {
    DashboardView()
        .environment(AuthSession.previewAuthenticated)
}
