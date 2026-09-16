import SwiftUI

/// El indicador de carga a pantalla completa.
///
/// Estaba escrito dos veces —`centeredLoading` en «Mi posición» y
/// `centeredLoadingPanel` en el panel del instructor— idéntico salvo el texto.
/// Se notó al partir los ficheros: uno de los dos era `private` a nivel de
/// fichero, y al mudarse de sitio dejó de alcanzar. Un duplicado que el
/// compilador señala es un duplicado con suerte.
///
/// El texto es obligatorio y no tiene valor por omisión: un indicador girando
/// sin decir qué está esperando no informa de nada, y quien mira esta pantalla
/// no tiene a quién preguntarle.
struct LoadingStateView: View {
    let text: String

    var body: some View {
        VStack(spacing: Theme.spacing.md.value) {
            ProgressView()
                .tint(Color.brand)
            Text(text)
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pageBackground()
        // Una sola frase: el indicador y su texto son el mismo mensaje.
        .accessibilityElement(children: .combine)
    }
}
