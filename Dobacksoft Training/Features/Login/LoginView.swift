import SwiftUI

struct LoginView: View {
    /// El formulario no crece más que esto.
    ///
    /// En iPad sin acotar se estiraba a 960 pt: dos campos de texto de un metro
    /// de ancho para escribir un correo. 420 pt es el ancho de un iPhone grande,
    /// que es la medida a la que este formulario está pensado.
    private static let maxFormWidth: CGFloat = 420

    @Environment(AuthSession.self) private var auth
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// Qué campo tiene el teclado. Es lo que permite que Return avance.
    @FocusState private var focus: LoginFormRules.Field?

    /// Hasta cuándo el servidor no acepta más intentos.
    ///
    /// El mensaje decía «Inténtelo de nuevo en 60 s» con el botón habilitado,
    /// invitando a un reintento que falla y que reinicia la ventana.
    @State private var retryUntil: Date?

    /// Si la pantalla es baja: iPhone en horizontal, o con el teclado fuera.
    private var isShort: Bool { verticalSizeClass == .compact }

    private func canSubmit(now: Date) -> Bool {
        LoginFormRules.canSubmit(
            email: email, password: password,
            retryUntil: retryUntil, now: now
        )
    }

    /// Si hay algo que explicar antes del formulario.
    private var hasSessionNotice: Bool {
        auth.canRetryRestore || auth.logoutReason?.notice != nil
    }

    var body: some View {
        // El `GeometryReader` es lo que permite las dos cosas a la vez: centrado
        // cuando el formulario cabe —como estaba— y scroll cuando no cabe. Con
        // los `Spacer()` de antes, en horizontal o con texto grande el botón se
        // iba por debajo de la pantalla y no había forma de alcanzarlo.
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Theme.spacing.lg.value) {
                    header
                    sessionNotice
                    form
                    footer
                }
                .frame(maxWidth: Self.maxFormWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.spacing.base.value)
                .padding(.vertical, Theme.spacing.lg.value)
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
            // Arrastrar hacia abajo cierra el teclado: en una pantalla baja el
            // teclado tapa el botón, y sin esto no queda nada que tocar fuera.
            .scrollDismissesKeyboard(.interactively)
            // Sin esto rebota siempre, también cuando no hay nada que scrollear.
            .scrollBounceBehavior(.basedOnSize)
        }
        .pageBackground()
        // Un golpe cuando el acceso falla.
        //
        // Es la única pantalla donde el resultado importa antes de leer nada:
        // quien teclea la contraseña con guantes, en un parque, con el
        // teléfono en una mano, se enteraba de que había fallado solo mirando.
        // El acierto NO vibra: la pantalla cambia entera, que ya es la señal.
        .sensoryFeedback(.error, trigger: errorMessage) { _, nuevo in nuevo != nil }
        // El foco arranca en el email: es lo que deja la pantalla lista para
        // teclear en cuanto aparece. Salvo cuando hay aviso de sesión — ahí el
        // teclado taparía el «Reintentar», que es justamente la salida que se
        // le está ofreciendo.
        .onAppear {
            guard !hasSessionNotice else { return }
            focus = .email
        }
    }

    // MARK: - Cabecera

    @ViewBuilder
    private var header: some View {
        VStack(spacing: Theme.spacing.md.value) {
            // El escudo son 56 pt que en horizontal no caben, y es decorativo:
            // lo primero que sobra cuando hay que elegir entre el adorno y el
            // botón de entrar.
            if !isShort {
                Image(systemName: "shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.brand)
                    .accessibilityHidden(true)
            }
            Text("Training")
                .font(.appTitle)
                .foregroundStyle(Color.ink)
            Text("CMadrid · Conductor de camión de bomberos")
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - El formulario

    @ViewBuilder
    private var form: some View {
        VStack(spacing: Theme.spacing.md.value) {
            TextField("Email", text: $email)
                .textFieldStyle(.themed)
                .font(.bodyText)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .email)
                .submitLabel(.next)
                .onSubmit { advance(from: .email) }
                .accessibilityLabel("Correo electrónico")
                .accessibilityIdentifier("login.email")

            SecureField("Contraseña", text: $password)
                .textFieldStyle(.themed)
                .font(.bodyText)
                .textContentType(.password)
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit { advance(from: .password) }
                .accessibilityLabel("Contraseña")
                .accessibilityIdentifier("login.password")

            if let errorMessage {
                Text(errorMessage)
                    .font(.bodyText)
                    .foregroundStyle(Color.danger)
                    .multilineTextAlignment(.center)
                    // Sin esto el texto se queda en una línea y se corta:
                    // «No se ha podido conectar. Compruebe s…». Es el único
                    // mensaje que ve alguien que no consigue entrar, así que
                    // truncado no le dice nada.
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Error: \(errorMessage)")
                    .accessibilityIdentifier("login.error")
            }

            // `TimelineView` para que la cuenta atrás corra sola: sin ella el
            // rótulo se quedaría en los segundos que había al pintarse.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let ahora = context.date
                let restan = LoginFormRules.secondsRemaining(until: retryUntil, now: ahora)

                Button {
                    submit()
                } label: {
                    if isLoading {
                        ProgressView()
                            // El indicador ocupa el sitio del rótulo del botón,
                            // así que sigue el mismo color que él.
                            .tint(Color.onBrand)
                    } else if let restan {
                        Text(LoginFormRules.waitLabel(secondsRemaining: restan))
                    } else {
                        Text("Iniciar sesión")
                    }
                }
                .buttonStyle(.brandPrimary)
                // `canSubmit` y no `isEmpty`: un campo con solo espacios estaba
                // habilitando el botón y gastando uno de los cinco intentos por
                // minuto en una petición que no podía funcionar.
                .disabled(isLoading || !canSubmit(now: ahora))
                .accessibilityLabel(
                    isLoading ? "Iniciando sesión"
                        : restan.map(LoginFormRules.waitLabel) ?? "Iniciar sesión"
                )
                .accessibilityIdentifier("login.submit")
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Pie

    @ViewBuilder
    private var footer: some View {
        Text("v1 · API \(AppEnvironment.baseURLHost ?? "sin configurar")")
            .font(.metaCaption)
            .foregroundStyle(Color.muted)
            .accessibilityHidden(true)
    }

    /// Por qué está viendo este formulario, cuando hay algo que explicar.
    ///
    /// Antes no había nada: quien perdía la cobertura al arrancar y quien tenía
    /// el refresh token caducado aterrizaban los dos aquí, en silencio. Los dos
    /// casos piden lo contrario — uno que espere, el otro que vuelva a entrar—
    /// y sin decirlo el formulario vacío se lee como «mi cuenta está rota».
    ///
    /// No es rojo. El rojo de `errorMessage` es para el intento que la persona
    /// acaba de hacer y ha fallado; esto es contexto de antes de tocar nada, y
    /// pintarlo como error propio sería culparla de una red caída.
    @ViewBuilder
    private var sessionNotice: some View {
        if auth.canRetryRestore {
            noticeCard(
                icon: "wifi.slash",
                text: SessionCopy.sessionSurvivesOffline,
                identifier: "login.notice.offline"
            ) {
                // La sesión está entera en el Keychain: lo que falta es poder
                // preguntar. Reintentar aquí evita teclear una contraseña que
                // ahora mismo tampoco puede funcionar.
                Button("Reintentar") {
                    Task { await auth.retryRestore() }
                }
                .buttonStyle(.brandPrimary)
                .accessibilityIdentifier("login.notice.retry")
            }
        } else if let notice = auth.logoutReason?.notice {
            noticeCard(
                icon: "clock.badge.exclamationmark",
                text: notice,
                identifier: "login.notice.expired"
            ) { EmptyView() }
        }
    }

    @ViewBuilder
    private func noticeCard<Action: View>(
        icon: String,
        text: String,
        identifier: String,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(spacing: Theme.spacing.sm.value) {
            HStack(alignment: .top, spacing: Theme.spacing.sm.value) {
                Image(systemName: icon)
                    .foregroundStyle(Color.brand)
                    .accessibilityHidden(true)
                Text(text)
                    .font(.bodyText)
                    .foregroundStyle(Color.ink)
                    // Las dos frases pasan de una línea en cualquier iPhone, y
                    // truncadas pierden justo la mitad que informa.
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            action()
        }
        .padding(Theme.spacing.base.value)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                .fill(Color.brandTint)
        )
        // Una sola parada de VoiceOver: el icono es decorativo y leer el texto
        // partido en trozos no ayuda a nadie.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(text)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Qué hace Return

    /// Return: del email al siguiente campo, del último a enviar.
    ///
    /// La decisión no vive aquí — vive en `LoginFormRules`, que sí se puede
    /// probar. Esto solo la aplica.
    private func advance(from field: LoginFormRules.Field) {
        if let next = LoginFormRules.nextField(after: field) {
            focus = next
            return
        }
        guard LoginFormRules.submitsOnReturn(from: field, email: email, password: password),
              canSubmit(now: Date()) else {
            // Formulario incompleto: se deja el foco donde está en lugar de
            // gastar un intento en una petición que va a fallar.
            return
        }
        submit()
    }

    private func submit() {
        guard !isLoading, canSubmit(now: Date()) else { return }
        // Se cierra el teclado antes de pedir: con el teclado fuera, el
        // indicador de carga del botón queda tapado y parece que no pasa nada.
        focus = nil
        Task { await login() }
    }

    private func login() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.login(
                // El email recortado, la contraseña tal cual se escribió.
                email: LoginFormRules.email(from: email),
                password: LoginFormRules.password(from: password)
            )
        } catch let err as APIError {
            // Si el servidor dice cuánto esperar, se le cree y se bloquea el
            // botón: un reintento antes de tiempo reinicia su ventana.
            if case .rateLimited(let retryAfter) = err {
                retryUntil = Date().addingTimeInterval(TimeInterval(retryAfter ?? 60))
            }
            fail(with: err.userMessage)
        } catch {
            fail(with: "Error inesperado: \(error.localizedDescription)")
        }
    }

    /// El error, escrito y dicho.
    ///
    /// Sin el anuncio el texto rojo aparecía en silencio: quien usa VoiceOver
    /// pulsaba «Iniciar sesión», no oía nada, y no tenía forma de saber que la
    /// pantalla ya le había contestado.
    private func fail(with message: String) {
        errorMessage = message
        AccessibilityNotification.Announcement(message).post()
    }
}

#Preview {
    LoginView()
        .environment(AuthSession())
}
