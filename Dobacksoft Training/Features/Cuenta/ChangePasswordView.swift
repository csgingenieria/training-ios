import SwiftUI

/// Cambiar la contraseña desde la app.
///
/// La única escritura de cuenta del API móvil, y el primer `PATCH` del
/// blueprint: excepción puntual y enumerada a la regla de solo lectura.
///
/// El formulario comprueba localmente lo poco que puede afirmar con certeza —
/// que las dos nuevas coinciden y que llega al mínimo— y **solo** para no
/// gastar uno de los cinco intentos por minuto. Si la actual es correcta lo
/// decide el servidor.
struct ChangePasswordView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var isSaving = false
    @State private var serverError: String?
    @State private var didSucceed = false
    @FocusState private var focus: Field?

    private enum Field { case current, new, confirm }

    var body: some View {
        Form {
            Section {
                SecureField("Contraseña actual", text: $current)
                    .textContentType(.password)
                    .focused($focus, equals: .current)
                    .submitLabel(.next)
                    .onSubmit { focus = .new }
                    .accessibilityIdentifier("password.current")

                SecureField("Contraseña nueva", text: $new)
                    .textContentType(.newPassword)
                    .focused($focus, equals: .new)
                    .submitLabel(.next)
                    .onSubmit { focus = .confirm }
                    .accessibilityIdentifier("password.new")

                SecureField("Repita la contraseña nueva", text: $confirm)
                    .textContentType(.newPassword)
                    .focused($focus, equals: .confirm)
                    .submitLabel(.go)
                    .onSubmit { if canSubmit { Task { await save() } } }
                    .accessibilityIdentifier("password.confirm")
            } footer: {
                // El aviso local, en cuanto se puede afirmar. No espera al
                // envío: avisar después de gastar un intento no sirve de nada.
                if let problema = localProblem {
                    Text(problema.message)
                        .foregroundStyle(Color.danger)
                } else {
                    Text("Al menos \(PasswordFormRules.minimumLength) caracteres.")
                }
            }

            if let serverError {
                Section {
                    Label(serverError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("password.error")
                }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().tint(Color.onBrand)
                    } else {
                        Text("Cambiar la contraseña")
                    }
                }
                .buttonStyle(.brandPrimary)
                .disabled(!canSubmit || isSaving)
                .accessibilityIdentifier("password.submit")
            } footer: {
                // Lo que NO cambia, dicho: la sesión sigue abierta, así que
                // nadie cierra la app pensando que tiene que volver a entrar.
                Text("Su sesión seguirá abierta en este dispositivo.")
            }
        }
        .navigationTitle("Contraseña")
        .onAppear { focus = .current }
        .alert("Contraseña cambiada", isPresented: $didSucceed) {
            Button("Aceptar") { dismiss() }
        } message: {
            Text("La próxima vez que inicie sesión, use la contraseña nueva.")
        }
    }

    private var localProblem: PasswordFormRules.LocalProblem? {
        PasswordFormRules.localProblem(new: new, confirm: confirm)
    }

    private var canSubmit: Bool {
        PasswordFormRules.canSubmit(current: current, new: new, confirm: confirm)
    }

    @MainActor
    private func save() async {
        serverError = nil
        isSaving = true
        defer { isSaving = false }

        do {
            try await auth.authorized { token in
                try await APIClient.shared.changePassword(
                    current: current,
                    new: new,
                    confirm: confirm,
                    accessToken: token
                )
            }
            // Se limpian los tres: la pantalla puede quedar viva detrás de la
            // alerta, y dejar la contraseña nueva escrita en un campo no aporta
            // nada y sí la deja a la vista de quien pase por detrás.
            current = ""; new = ""; confirm = ""
            didSucceed = true
        } catch let error as APIError {
            serverError = message(for: error)
        } catch {
            serverError = PasswordFormRules.message(forServerError: nil)
        }
    }

    /// El mensaje del servidor traducido.
    ///
    /// `APIError.validation` trae el texto del backend, pero el cliente prefiere
    /// su propia frase por la clave: el backend manda claves de máquina y las
    /// suyas están en un vocabulario que la app ya sabe redactar.
    private func message(for error: APIError) -> String {
        switch error {
        case .validation(let mensaje, _):
            // El blueprint manda `{"error": clave, "message": texto}` y el
            // cliente guarda el texto; la clave no llega tipada, así que se usa
            // el texto cuando no hay nada mejor.
            mensaje.isEmpty ? PasswordFormRules.message(forServerError: nil) : mensaje
        case .rateLimited:
            error.userMessage
        default:
            error.userMessage
        }
    }
}
