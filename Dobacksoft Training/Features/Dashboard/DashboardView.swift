import SwiftUI

/// Entrada principal post-login. Adaptativo según size class:
/// - Compact (iPhone, iPad Slide Over): `TabView` nativo.
/// - Regular (iPad portrait/landscape): `NavigationSplitView` con sidebar.
///
/// Regla D-IOS-001: iPhone + iPad mismo target, layout adaptativo.
struct DashboardView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .regular {
                splitLayout
            } else {
                tabLayout
            }
        }
        .tint(Color.brand)
    }

    // MARK: - iPhone / Compact

    @ViewBuilder
    private var tabLayout: some View {
        TabView {
            if auth.user?.isAdminLike == true {
                Tab("Panel", systemImage: "chart.bar.doc.horizontal") {
                    NavigationStack {
                        ManagerPanelView()
                    }
                }
            }

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

    // MARK: - iPad / Regular

    @ViewBuilder
    private var splitLayout: some View {
        SidebarDashboard()
    }
}

/// Layout iPad con sidebar permanente. La sección seleccionada se renderea en el
/// detail. Mantiene `NavigationStack` por sección para que cada drill-down
/// (detalle de convocatoria, ranking, intento) navegue dentro del detail pane.
private struct SidebarDashboard: View {
    @Environment(AuthSession.self) private var auth
    @State private var selection: SidebarSection? = .convocatorias

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Inicio") {
                    if auth.user?.isAdminLike == true {
                        sidebarItem(.panel)
                    }
                    sidebarItem(.convocatorias)
                    if auth.user?.isStudent == true {
                        sidebarItem(.miPosicion)
                    }
                }
                Section("Cuenta") {
                    sidebarItem(.perfil)
                }
            }
            .navigationTitle("Training")
        } detail: {
            NavigationStack {
                detailView(for: selection ?? .convocatorias)
            }
        }
        .onAppear {
            // Si el rol no coincide con la sección por default, autoseleccionar.
            if selection == .convocatorias, auth.user?.isAdminLike == true {
                selection = .panel
            }
        }
    }

    @ViewBuilder
    private func sidebarItem(_ section: SidebarSection) -> some View {
        Label(section.title, systemImage: section.icon)
            .tag(section as SidebarSection?)
    }

    @ViewBuilder
    private func detailView(for section: SidebarSection) -> some View {
        switch section {
        case .panel:         ManagerPanelView()
        case .convocatorias: ConvocatoriasListView()
        case .miPosicion:    MyStandingTabView()
        case .perfil:        ProfileView()
        }
    }
}

private enum SidebarSection: Hashable {
    case panel, convocatorias, miPosicion, perfil

    var title: String {
        switch self {
        case .panel:         return "Panel"
        case .convocatorias: return "Convocatorias"
        case .miPosicion:    return "Mi posición"
        case .perfil:        return "Perfil"
        }
    }

    var icon: String {
        switch self {
        case .panel:         return "chart.bar.doc.horizontal"
        case .convocatorias: return "list.bullet.rectangle"
        case .miPosicion:    return "trophy.fill"
        case .perfil:        return "person.crop.circle"
        }
    }
}

// MARK: - Profile

struct ProfileView: View {
    @Environment(AuthSession.self) private var auth
    @State private var showLogoutConfirmation = false
    @State private var quickViewEnabled = SnapshotPublisher.shared.isQuickViewEnabled
    @State private var serverHealth: String?

    var body: some View {
        Form {
            if let user = auth.user {
                Section {
                    profileHeader(user)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: Theme.spacing.lg.value, leading: 0, bottom: Theme.spacing.lg.value, trailing: 0))
                }

                Section("Mi cuenta") {
                    row("Nombre", value: user.name)
                    row("Email", value: user.email)
                    row("Rol", value: user.role.capitalized)
                    if let orgId = user.organizationId {
                        row("Organización", value: orgId)
                    }
                }
            }

            Section {
                Toggle("Mostrar mi posición en el widget", isOn: $quickViewEnabled)
                    .tint(Color.brand)
                    .onChange(of: quickViewEnabled) { _, enabled in
                        // Al apagarlo se publica «desactivado», que no revela
                        // nada. Al encenderlo, el estado que corresponda al rol;
                        // la posición real llega al abrir «Mi posición».
                        SnapshotPublisher.shared.setQuickViewEnabled(enabled) {
                            auth.user?.isStudent == true ? .sinDatosAun : .sinPosicionPropia
                        }
                    }
            } header: {
                Text("Vista rápida")
            } footer: {
                Text("El widget muestra su puesto y su nota en la pantalla de inicio, donde puede verlos cualquier persona que mire el dispositivo. Viene desactivado.")
            }

            Section("API") {
                row("Base URL", value: AppEnvironment.baseURLHost ?? "sin configurar")
                row("Cliente", value: AppEnvironment.clientVersion)
                // El endpoint de salud existía en el contrato y en el cliente,
                // y no lo llamaba nadie. Aquí sirve para lo que sirve: saber si
                // el problema es del servidor antes de llamar a soporte.
                row("Estado del servidor", value: serverHealth ?? "comprobando…")
            }

            Section("Acerca de") {
                row("Versión", value: Self.appVersion)
                row("Build", value: Self.buildNumber)
                row("Aplicación", value: "Dobacksoft Training")
            }

            Section {
                Button(role: .destructive) {
                    showLogoutConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Cerrar sesión")
                    }
                    .font(.bodyEmphasis)
                }
                .accessibilityLabel("Cerrar sesión")
            }
        }
        .task { await checkHealth() }
        .navigationTitle("Perfil")
        .confirmationDialog(
            "¿Cerrar sesión?",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cerrar sesión", role: .destructive) {
                Task { await auth.logout() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Vas a salir de la app y tendrás que iniciar sesión de nuevo.")
        }
    }

    @ViewBuilder
    private func profileHeader(_ user: UserDTO) -> some View {
        HStack(spacing: Theme.spacing.base.value) {
            ZStack {
                Circle()
                    .fill(Color.brandTint)
                Text(user.name.prefix(1).uppercased())
                    .font(.display(size: 28, weight: .bold, italic: true, relativeTo: .title))
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
        .padding(.horizontal, Theme.spacing.base.value)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func row(_ label: String, value: String) -> some View {
        LabeledContent {
            Text(value)
                .font(.bodyText)
                .foregroundStyle(Color.inkSecondary)
        } label: {
            Text(label)
                .font(.bodyText)
                .foregroundStyle(Color.muted)
        }
    }

    /// Consulta el endpoint de salud.
    ///
    /// No es autenticado y no toca `authorized`: si la sesión estuviera rota,
    /// esta comprobación es justo la que dice si el problema es del servidor.
    private func checkHealth() async {
        do {
            let health = try await APIClient.shared.health()
            serverHealth = [health.status, health.version]
                .compactMap { $0 }
                .joined(separator: " · ")
        } catch let error as APIError {
            serverHealth = error.userMessage
        } catch {
            serverHealth = "No disponible"
        }
    }

    private static var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "—"
    }

    private static var buildNumber: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "—"
    }
}

#Preview {
    DashboardView()
        .environment(AuthSession.previewAuthenticated)
}
