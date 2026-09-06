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
