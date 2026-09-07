import SwiftUI

struct LoginView: View {
    @Environment(AuthSession.self) private var auth
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Theme.spacing.lg.value) {
            Spacer()

            VStack(spacing: Theme.spacing.md.value) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.brand)
                    .accessibilityHidden(true)
                Text("Training")
                    .font(.appTitle)
                    .foregroundStyle(Color.ink)
                Text("CMadrid · Conductor de camión de bomberos")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
            }

            sessionNotice

            VStack(spacing: Theme.spacing.md.value) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .font(.bodyText)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Correo electrónico")
                    .accessibilityIdentifier("login.email")

                SecureField("Contraseña", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .font(.bodyText)
                    .textContentType(.password)
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
                }

                Button {
                    Task { await login() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Iniciar sesión")
                    }
                }
                .buttonStyle(.brandPrimary)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                .accessibilityLabel(isLoading ? "Iniciando sesión" : "Iniciar sesión")
                .accessibilityIdentifier("login.submit")
            }
            .padding(.horizontal, Theme.spacing.xl.value)

            Spacer()

            Text("v1 · API \(AppEnvironment.baseURLHost ?? "sin configurar")")
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
                .accessibilityHidden(true)
        }
        .padding()
        .pageBackground()
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
        .padding(.horizontal, Theme.spacing.xl.value)
        // Una sola parada de VoiceOver: el icono es decorativo y leer el texto
        // partido en trozos no ayuda a nadie.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(text)
        .accessibilityIdentifier(identifier)
    }

    private func login() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.login(email: email, password: password)
        } catch let err as APIError {
            errorMessage = err.userMessage
        } catch {
            errorMessage = "Error inesperado: \(error.localizedDescription)"
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthSession())
}
