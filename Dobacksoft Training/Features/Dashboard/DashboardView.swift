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

    /// Opcional por lo mismo que el ticker: las previsualizaciones no lo
    /// inyectan.
    @Environment(DeepLinkInbox.self) private var deepLinks: DeepLinkInbox?

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
            // Y después el enlace, que manda sobre lo restaurado: llegó porque
            // alguien acaba de tocar el widget.
            openPendingLink()
        }
        .onChange(of: router.section) { _, section in
            storedSection = section.rawValue
        }
        .onChange(of: deepLinks?.pending) { _, _ in
            // La app ya estaba abierta cuando llegó el toque.
            openPendingLink()
        }
        .background(sectionShortcuts)
    }

    /// ⌘1 … ⌘n para saltar de sección con teclado.
    ///
    /// Botones invisibles y de tamaño cero: un `keyboardShortcut` necesita
    /// colgar de un control, y no hay uno visible al que colgarlo sin inventar
    /// una fila de botones que nadie ha pedido. Van tras `.accessibilityHidden`
    /// porque un botón sin rótulo en el recorrido de VoiceOver es ruido.
    ///
    /// Se numeran sobre las secciones DEL ROL: para un aspirante ⌘1 es
    /// Convocatorias y para un instructor es el Panel, igual que el orden que
    /// ve en pantalla. Numerar sobre la lista completa daría atajos a huecos.
    @ViewBuilder
    private var sectionShortcuts: some View {
        ForEach(Array(sections.prefix(9).enumerated()), id: \.element) { indice, section in
            Button("") { router.select(section) }
                .keyboardShortcut(
                    KeyEquivalent(Character("\(indice + 1)")),
                    modifiers: .command
                )
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    /// Atiende el enlace que estuviera esperando.
    ///
    /// `select` decide si el rol puede ir: un instructor que toque un widget
    /// dejado por otra sesión se queda donde está, en vez de aterrizar en una
    /// pantalla cuyos endpoints le rechazan.
    private func openPendingLink() {
        guard let link = deepLinks?.consume() else { return }
        router.select(link.section)
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

    /// El binding de las pestañas pasa por `select` para que la sección quede
    /// acotada al rol. `select` ya NO hace pop: una escritura del valor actual
    /// —que SwiftUI hace al reconciliar— vaciaba la pila y tiraba la pantalla
    /// que la persona tenía abierta.
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
        // `NavigationLink(value:)` dentro del `List(selection:)`, que es el
        // patrón que Apple documenta para el sidebar de un
        // `NavigationSplitView`.
        //
        // Antes era un `Label` con `.tag()`, y así una fila de List en iOS
        // **no es seleccionable al toque** fuera del modo edición. El proyecto
        // lo tenía anotado como un límite de XCUITest —«no acciona la
        // selección de un List de SwiftUI», seis aproximaciones probadas— y
        // hasta se trabajó alrededor en el producto por esa creencia.
        //
        // No era la herramienta. La fila mide 288×52 pt, está donde dice estar,
        // se toca en su centro y el panel de detalle no se movía. En iPad este
        // sidebar es la vía principal de todo.
        NavigationLink(value: section) {
            Label(section.title, systemImage: section.icon)
        }
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
    @State private var serverHealth: ServerHealthPresentation = .checking

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
                        NavigationLink("Mi PIN de tablet", value: ProfileRoute.pin)
                            .accessibilityIdentifier("profile.pin")
                    }
                    NavigationLink("Cambiar la contraseña", value: ProfileRoute.password)
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

            Section {
                row("Base URL", value: AppEnvironment.baseURLHost ?? "sin configurar")
                row("Cliente", value: AppEnvironment.clientVersion)
                // El endpoint de salud existía en el contrato y no lo llamaba
                // nadie. Aquí sirve para lo que sirve: saber si el problema es
                // del servidor antes de llamar a soporte.
                //
                // Es un BOTÓN: `checkHealth()` corría una vez por aparición y
                // no había forma de volver a preguntar, que es justo lo que se
                // quiere hacer con un servidor que estaba caído hace un minuto.
                Button {
                    Task { await checkHealth() }
                } label: {
                    LabeledContent {
                        HStack(spacing: Theme.spacing.xs.value) {
                            if serverHealth == .checking {
                                ProgressView().controlSize(.mini)
                            }
                            Text(serverHealth.value)
                                .font(.bodyText)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    } label: {
                        Text("Estado del servidor")
                            .font(.bodyText)
                            .foregroundStyle(Color.muted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!serverHealth.canRecheck)
                .accessibilityIdentifier("profile.health")
                .accessibilityHint("Tocar para volver a comprobar")
            } header: {
                Text("API")
            } footer: {
                // La frase va aquí, no en la columna de valor. Antes «No se ha
                // podido conectar. Compruebe su conexión a la red.» se metía en
                // el hueco donde cabe «Disponible» y se comía la fila.
                if let detalle = serverHealth.footer {
                    Text(detalle)
                }
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
                // El diálogo cuelga del BOTÓN, no de la pantalla.
                //
                // En iPad se presenta como popover y apunta a lo que lo lanzó:
                // colgado del `Form` aparecía en el centro, sin flecha a nada,
                // y no se sabía qué acción se estaba confirmando.
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
        }
        .task { await checkHealth() }
        // Por VALOR, como el resto. Estos dos eran los últimos enlaces de
        // destino de la app y se le escaparon al barrido anterior: buscaba
        // `NavigationLink {` y esta forma pone el rótulo como primer argumento.
        // Un patrón de búsqueda que no cubre todas las formas del defecto deja
        // el defecto y la sensación de haberlo barrido.
        .navigationDestination(for: ProfileRoute.self) { route in
            switch route {
            case .pin:      MyPinView()
            case .password: ChangePasswordView()
            }
        }
        .navigationTitle("Perfil")
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

            VStack(alignment: .leading, spacing: Theme.spacing.xxs.value) {
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
        serverHealth = .checking
        do {
            serverHealth = .from(.success(try await APIClient.shared.health()))
        } catch {
            serverHealth = .from(.failure(error))
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

/// Lo que se puede abrir desde el perfil.
nonisolated enum ProfileRoute: Hashable {
    case pin
    case password
}
