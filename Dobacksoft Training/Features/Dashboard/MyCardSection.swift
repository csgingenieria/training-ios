import SwiftUI
import os

/// Con qué tarjeta va a conducir, en el perfil.
///
/// Va en el perfil y no en el panel porque es donde el aspirante busca sus
/// datos, y porque el caso de uso es de antes de la prueba, no del momento de
/// conducir: si no tiene tarjeta hay que enterarse con tiempo, no delante del
/// camión.
///
/// **No lee el chip.** Enseña lo que el sistema tiene registrado para que la
/// comparación la haga la persona, mirando el plástico.
struct MyCardSection: View {
    @Environment(AuthSession.self) private var auth
    @State private var state: CardState = .loading

    enum CardState {
        case loading
        case loaded(CardDTO)
        /// No se pudo preguntar. Distinto de «no tiene tarjeta»: aquí no se
        /// sabe, y decirle que no tiene sería afirmar de más.
        case unavailable
    }

    var body: some View {
        Section {
            switch state {
            case .loading:
                HStack(spacing: Theme.spacing.sm.value) {
                    ProgressView().controlSize(.small)
                    Text("Comprobando su tarjeta…")
                        .font(.metaCaption)
                        .foregroundStyle(Color.muted)
                }

            case .loaded(let card):
                if let uid = card.cardUid {
                    LabeledContent("Tarjeta") {
                        // Monoespaciada: se compara carácter a carácter contra
                        // lo impreso en el plástico, y una proporcional junta
                        // los dígitos parecidos.
                        Text(uid)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .accessibilityLabel("Tarjeta \(uid.map(String.init).joined(separator: " "))")
                }

                if let driver = card.webfleetDriverNo {
                    LabeledContent("Conductor en la flota", value: driver)
                }

                if card.needsInstructor {
                    Label(MyCardCopy.noCard, systemImage: "exclamationmark.triangle.fill")
                        .font(.metaCaption)
                        .foregroundStyle(Color.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }

            case .unavailable:
                // Ni «tiene» ni «no tiene»: no se pudo preguntar, y el
                // aspirante necesita saber que la respuesta falta, no una
                // respuesta inventada en cualquiera de los dos sentidos.
                Text(MyCardCopy.unavailable)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Con qué conduce")
        } footer: {
            if case .loaded(let card) = state, card.canDriveToday {
                Text(MyCardCopy.compareWithThePlastic)
            }
        }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        do {
            let card = try await auth.authorized { token in
                try await APIClient.shared.myCard(accessToken: token)
            }
            state = .loaded(card)
        } catch {
            AppLog.api.notice("No se pudo consultar la tarjeta: \(String(describing: error), privacy: .public)")
            state = .unavailable
        }
    }
}

/// Lo que dice la sección de la tarjeta.
nonisolated enum MyCardCopy {
    /// Por qué mirar esto antes de la prueba y no durante.
    static let compareWithThePlastic =
        "Compruebe que coincide con el número impreso en su tarjeta antes del día de la prueba."

    /// Sin tarjeta no se puede abrir un intento, y hay que decirlo con la
    /// salida incluida: el aspirante no puede resolverlo solo.
    static let noCard =
        "No tiene ninguna tarjeta asignada. Sin ella no se puede abrir un intento: avise a su instructor antes de la prueba."

    /// No se pudo preguntar. No se afirma que tenga ni que no tenga.
    static let unavailable =
        "No se ha podido consultar su tarjeta. Vuelva a abrir esta pantalla cuando tenga conexión."
}
