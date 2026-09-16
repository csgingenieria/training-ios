import SwiftUI

/// El PIN de tablet del aspirante.
///
/// Existe para que nadie dependa de que otro se lo dicte.
///
/// ⚠ **El backend audita cada consulta**, también cuando el PIN no se puede
/// mostrar. Por eso es una pantalla aparte y no una fila del perfil: se carga
/// cuando la persona entra a verla, no de fondo, y no hay `refreshable` — un
/// gesto involuntario no debe dejar rastro en el registro de auditoría de
/// alguien.
struct MyPinView: View {
    @Environment(AuthSession.self) private var auth
    @State private var state: PinState = .loading

    enum PinState {
        case loading
        case loaded(PinDTO)
        case error(String)
    }

    var body: some View {
        ScrollView {
            content
                .readableWidth()
                .padding(.horizontal, Theme.spacing.base.value)
                .padding(.vertical, Theme.spacing.base.value)
        }
        .pageBackground()
        // En una corrida de test la credencial no se dibuja. Ver
        // `SecretRedaction`: el test no la captura, pero XCTest saca capturas
        // del sistema por su cuenta y las conserva cuando el test falla.
        .redactedInUITests()
        .accessibilityIdentifier("pin.pantalla")
        .navigationTitle("Mi PIN")
        // Sin `.refreshable` a propósito: cada consulta se audita, y tirar de
        // la pantalla sin querer no debe dejar una entrada en el registro.
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            VStack(spacing: Theme.spacing.md.value) {
                ProgressView().tint(Color.brand)
                Text("Consultando su PIN…")
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 200)

        case .loaded(let datos):
            VStack(spacing: Theme.spacing.lg.value) {
                pinCard(datos)
                if !datos.activeEnrollments.isEmpty {
                    enrollmentsCard(datos)
                }
                privacyNote
            }

        case .error(let mensaje):
            ContentUnavailableView {
                Label("No se ha podido consultar su PIN", systemImage: "exclamationmark.triangle.fill")
            } description: {
                Text(mensaje)
            } actions: {
                Button("Reintentar") { Task { await load() } }
                    .buttonStyle(.brandPrimary(fullWidth: false))
                    .accessibilityIdentifier("pin.retry")
            }
            .cardStyle()
        }
    }

    @ViewBuilder
    private func pinCard(_ datos: PinDTO) -> some View {
        VStack(spacing: Theme.spacing.sm.value) {
            Text("Su PIN")
                .font(.metaCaption)
                .foregroundStyle(Color.muted)

            if let pin = datos.pin {
                // Monoespaciada y espaciada: se teclea en una tablet, dígito a
                // dígito, y una proporcional junta el 1 con el 7.
                Text(pin)
                    .font(.pinDisplay)
                    .foregroundStyle(Color.ink)
                    .textSelection(.enabled)
                    // Marcado como sensible. El widget ya marcaba así sus
                    // cifras y el target de la app no lo usaba en ningún sitio,
                    // teniendo aquí lo más sensible que muestra: con el PIN y el
                    // número de inscripción se puede conducir en nombre de otro.
                    //
                    // **No redacta por sí solo en el conmutador de apps** —eso
                    // pide aplicar `.redacted(reason: .privacy)` desde el
                    // exterior, y es el punto #40 de la auditoría—. Es el
                    // marcador correcto para que esa redacción, cuando llegue,
                    // sepa qué tapar. Decir que ya tapa algo sería falso.
                    .privacySensitive()
                    .accessibilityLabel("Su PIN es \(pin.map(String.init).joined(separator: " "))")
            } else {
                // No poder mostrarlo NO impide conducir, y la frase lo dice: el
                // acceso lo valida el hash, que sigue funcionando.
                Text(PinCopy.unavailable)
                    .font(.bodyText)
                    .foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(PinCopy.tabletNeedsBoth)
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    @ViewBuilder
    private func enrollmentsCard(_ datos: PinDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm.value) {
            Text("Su número de inscripción")
                .font(.cardTitle)
                .foregroundStyle(Color.ink)

            ForEach(datos.activeEnrollments) { inscripcion in
                HStack(alignment: .firstTextBaseline) {
                    Text(inscripcion.name ?? "Convocatoria")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                    Spacer()
                    Text(inscripcion.plaza ?? "—")
                        // La otra mitad de la credencial.
                        .privacySensitive()
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.ink)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private var privacyNote: some View {
        HStack(alignment: .top, spacing: Theme.spacing.sm.value) {
            Image(systemName: "lock.fill")
                .foregroundStyle(Color.muted)
                .accessibilityHidden(true)
            Text(PinCopy.keepItPrivate)
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @MainActor
    private func load() async {
        do {
            let datos = try await auth.authorized { token in
                try await APIClient.shared.myPin(accessToken: token)
            }
            state = .loaded(datos)
        } catch let error as APIError {
            state = .error(error.userMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
