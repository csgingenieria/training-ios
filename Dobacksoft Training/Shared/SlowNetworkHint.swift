import SwiftUI

/// Cuándo decir que la red está tardando.
///
/// Con el tiempo de espera en quince segundos, una pantalla podía estar
/// girando quince segundos sin que nada dijera si iba a llegar algo. Un
/// indicador que gira significa «espera»; a los cuatro segundos ya significa
/// «esto no va».
nonisolated enum SlowNetworkHint {
    /// A partir de cuándo se avisa.
    ///
    /// Cuatro segundos: por debajo es una carga normal y el aviso sería ruido
    /// en cada apertura de pantalla.
    static let threshold: TimeInterval = 4

    static let message = "Está tardando más de lo habitual. Compruebe su conexión a la red."
}

/// Un esqueleto en vez de un indicador centrado.
///
/// Las pantallas parpadeaban un indicador en medio y el contenido aparecía
/// después a otra altura, así que la página saltaba. `redacted` estaba sin usar
/// en toda la app teniéndolo el sistema de serie.
///
/// Y con el aviso de red lenta encima, que es lo que convierte una espera en
/// información.
struct LoadingSkeleton<Content: View>: View {
    private let content: Content

    @State private var isSlow = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: Theme.spacing.md.value) {
            content
                // El esqueleto es la MISMA forma que va a aparecer, así que la
                // pantalla no salta al llegar los datos.
                .redacted(reason: .placeholder)
                // Ni se lee ni se toca: es una forma, no un dato. Sin esto
                // VoiceOver leería las cifras de relleno como si fueran de
                // alguien.
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            if isSlow {
                Text(SlowNetworkHint.message)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                    .accessibilityIdentifier("loading.slow")
            }
        }
        .task {
            // Se cancela sola al desaparecer la vista, que es lo que hace que
            // el aviso no salga sobre una pantalla ya cargada.
            try? await Task.sleep(for: .seconds(SlowNetworkHint.threshold))
            guard !Task.isCancelled else { return }
            isSlow = true
        }
    }
}
