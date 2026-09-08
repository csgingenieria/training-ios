import SwiftUI

/// Entrada principal post-login. Adaptativo según size class:
/// - Compact (iPhone, iPad Slide Over): `TabView` nativo.
/// - Regular (iPad portrait/landscape): `NavigationSplitView` con sidebar.
///
/// Regla D-IOS-001: iPhone + iPad mismo target, layout adaptativo.
///
/// Los dos layouts comparten un `DashboardRouter`. Antes eran dos árboles de
/// vistas sin nada en común, así que arrastrar un Split View o girar un iPhone
/// Pro Max tiraba todas las pantallas abiertas y sus view models.
struct DashboardView: View {
    @Environment(AuthSession.self) private var auth

    var body: some View {
        // La identidad depende del rol: entrar con otra cuenta es otro
        // dashboard, y sus pilas de navegación no se heredan.
        DashboardContent(
            isAdminLike: auth.user?.isAdminLike == true,
            isStudent: auth.user?.isStudent == true
        )
        .id(auth.user?.role ?? "")
    }
}

private struct DashboardContent: View {
    let isAdminLike: Bool
    let isStudent: Bool

    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var router: DashboardRouter
    @SceneStorage("dashboard.section") private var storedSection: String = ""
    @State private var hasRestoredSection = false

    init(isAdminLike: Bool, isStudent: Bool) {
        self.isAdminLike = isAdminLike
        self.isStudent = isStudent
        _router = State(initialValue: DashboardRouter(isAdminLike: isAdminLike, isStudent: isStudent))
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                splitLayout
            } else {
                tabLayout
            }
        }
        .tint(Color.brand)
        .task {
            // Una sola vez: `.task` vuelve a correr al cambiar de size class,
            // y restaurar otra vez devolvería la sección a la raíz en cada
            // giro del dispositivo.
            guard !hasRestoredSection else { return }
            hasRestoredSection = true
            // `select` ya acota lo que el rol no puede usar, así que una
            // sección restaurada que no le corresponde se ignora sola.
            if let restored = SidebarSection(rawValue: storedSection) {
                router.select(restored)
            }
        }
        .onChange(of: router.section) { _, section in
            storedSection = section.rawValue
        }
    }

    private var sections: [SidebarSection] {
        SidebarSection.available(isAdminLike: isAdminLike, isStudent: isStudent)
    }

    // MARK: - iPhone / Compact

    @ViewBuilder
    private var tabLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(sections) { section in
                Tab(section.title, systemImage: section.icon, value: section) {
                    NavigationStack(path: router.pathBinding(for: section)) {
                        root(for: section)
                    }
                }
            }
        }
    }

    /// El binding de las pestañas pasa por `select`, no por `section` directo:
    /// así tocar la pestaña que ya se está viendo la devuelve a su raíz, que es
    /// lo que hace la plataforma.
    private var tabSelection: Binding<SidebarSection> {
        Binding(
            get: { router.section },
            set: { router.select($0) }
        )
    }

    // MARK: - iPad / Regular

    /// Layout iPad con sidebar permanente. Una pila de navegación **por
    /// sección**, con su `path` enlazado: antes era una sola sin `path`, así
    /// que cambiar de sección estando dentro de una convocatoria dejaba puesta
    /// la pila de la sección anterior.
    @ViewBuilder
    private var splitLayout: some View {
        NavigationSplitView {
            List(selection: sidebarSelection) {
                Section("Inicio") {
                    ForEach(sections.filter { $0 != .perfil }) { sidebarItem($0) }
                }
                Section("Cuenta") {
                    sidebarItem(.perfil)
                }
            }
            .navigationTitle("Training")
        } detail: {
            NavigationStack(path: router.pathBinding(for: router.section)) {
                root(for: router.section)
            }
            // Identidad por sección: cambiar de sección cambia a la vez la
            // raíz y el `path`, y sin identidad propia SwiftUI intenta
            // reconciliar una pila con la de otra pantalla. Reconstruirla no
            // pierde nada — el camino vive en el router, no en la pila.
            .id(router.section)
        }
    }

    private var sidebarSelection: Binding<SidebarSection?> {
        Binding(
            get: { router.section },
            set: { if let section = $0 { router.select(section) } }
        )
    }

    @ViewBuilder
    private func sidebarItem(_ section: SidebarSection) -> some View {
        Label(section.title, systemImage: section.icon)
            .tag(section as SidebarSection?)
            // Una fila de este sidebar cambia el panel de detalle, así que es
            // un botón y conviene que se anuncie como tal: VoiceOver decía
            // solo el texto, sin decir que se puede activar.
            //
            // Tiene además un efecto práctico: sin el rasgo, la fila llega a
            // XCUITest como una celda sin etiqueta con un texto dentro, y
            // ningún toque sintético —sobre el texto, sobre la celda o por
            // coordenada— movía la selección. El recorrido automatizado no
            // podía entrar en ninguna pantalla en iPad.
            // `combine` primero: sin él el identificador caía en el ICONO del
            // Label —25×20 pt y no accionable— en vez de en la fila entera.
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("sidebar.\(section.identifier)")
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func root(for section: SidebarSection) -> some View {
        switch section {
        case .panel:         ManagerPanelView()
        case .convocatorias: ConvocatoriasListView()
        case .miPosicion:    MyStandingTabView()
        case .miProgreso:    ProgresoView()
        case .perfil:        ProfileView()
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
                    row("Rol", value: StatusVocabulary.role(user.role))
                    // La organización se enseñaba con su identificador de
                    // base de datos —un UUID— a un bombero. El nombre no
                    // viaja en `GET /me`, así que hasta que lo haga es mejor
                    // no decir nada que decir un dato que no significa nada
                    // para quien lo lee. Queda pedido al backend.
                }

                // Solo el aspirante conduce, así que solo a él le sirve saber
                // con qué tarjeta. El endpoint es STUDENT-only de todas formas.
                if user.isStudent {
                    MyCardSection()
                }

                Section("Acceso") {
                    // El PIN va detrás de un toque, no en una fila: el backend
                    // audita CADA consulta, y una fila que se carga sola
                    // dejaría una entrada en el registro por abrir el perfil.
                    if user.isStudent {
                        NavigationLink("Mi PIN de tablet") { MyPinView() }
                            .accessibilityIdentifier("profile.pin")
                    }
                    NavigationLink("Cambiar la contraseña") { ChangePasswordView() }
                        .accessibilityIdentifier("profile.password")
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
                Task { await auth.logout(reason: .userInitiated) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Saldrá de la aplicación y tendrá que iniciar sesión de nuevo.")
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
            StatusBadge(text: StatusVocabulary.role(user.role), kind: .brand)
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
