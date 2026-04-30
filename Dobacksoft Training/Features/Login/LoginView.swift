import SwiftUI

struct LoginView: View {
    @Environment(AuthSession.self) private var auth
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Training")
                    .font(.system(size: 40, weight: .bold))
                Text("CMadrid · Conductor de camión de bomberos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Contraseña", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                Button {
                    Task { await login() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .tint(.white)
                    } else {
                        Text("Iniciar sesión")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
            }
            .padding(.horizontal, 32)

            Spacer()

            Text("v1 · API \(AppEnvironment.baseURL.host() ?? "")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
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
