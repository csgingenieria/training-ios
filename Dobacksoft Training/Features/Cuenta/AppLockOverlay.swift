import SwiftUI

/// La pantalla tapada mientras el bloqueo opcional no se resuelve.
///
/// **Siempre con dos salidas.** «Desbloquear» y «Cerrar sesión»: sin la
/// segunda, alguien que no puede autenticarse en ese momento —el sensor
/// sucio, un código que no recuerda— se queda encerrado en una pantalla sin
/// nada que pulsar, con su sesión dentro.
struct AppLockOverlay: View {
    let onUnlock: () -> Void
    let onSignOut: () -> Void

    /// `true` mientras el diálogo del sistema está en pantalla: los botones no
    /// se pueden pulsar entonces, y dejarlos activos invitaría a un segundo
    /// diálogo sobre el primero.
    let isAsking: Bool

    var body: some View {
        ZStack {
            Color.paper
                .ignoresSafeArea()

            VStack(spacing: Theme.spacing.lg.value) {
                Image(systemName: "lock.fill")
                    .font(.heroGlyph)
                    .foregroundStyle(Color.brand)
                    .accessibilityHidden(true)

                Text("Aplicación bloqueada")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.ink)

                Text("Confirme que es usted para ver su puesto y su nota.")
                    .font(.bodyText)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Las salidas se PINTAN desde `AppLockRules.exitsAfterFailure`.
                //
                // Estaban escritas a mano aquí y la constante solo existía para
                // que un test la leyera: el test afirmaba que había una salida
                // sin que quitarla de la pantalla lo hiciera fallar. Un test
                // que mide una constante y no la pantalla es exactamente el
                // agujero que este repo lleva todo el día cerrando.
                VStack(spacing: Theme.spacing.sm.value) {
                    ForEach(AppLockRules.exitsAfterFailure, id: \.self) { exit in
                        switch exit {
                        case .retry:
                            Button("Desbloquear", action: onUnlock)
                                .buttonStyle(.brandPrimary(fullWidth: true))
                                .disabled(isAsking)
                                .accessibilityIdentifier("applock.unlock")

                        case .signOut:
                            // La salida. No es un adorno: es lo que separa un
                            // bloqueo de una trampa.
                            Button("Cerrar sesión", action: onSignOut)
                                .font(.bodyText)
                                .foregroundStyle(Color.inkSecondary)
                                .disabled(isAsking)
                                .accessibilityIdentifier("applock.signout")
                        }
                    }
                }
            }
            .readableWidth()
            .padding(Theme.spacing.base.value)
        }
        .accessibilityIdentifier("applock.pantalla")
    }
}
