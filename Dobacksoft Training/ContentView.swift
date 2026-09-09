import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var auth
    @Environment(\.scenePhase) private var scenePhase

    /// Vive aquí, y no en el dashboard, porque tiene que sobrevivir a un
    /// cambio de size class: es lo único que sabe que la persona se fue.
    @State private var ticker = RefreshTicker()

    /// Y esto vive aquí porque un arranque en frío desde el widget entrega la
    /// URL mientras todavía está la pantalla de carga: el dashboard, que es
    /// quien puede atenderla, no existe todavía.
    /// El buzón compartido, no uno propio: un `AppIntent` de Siri deja su
    /// destino en `DeepLinkInbox.shared`, y con dos buzones el enlace del
    /// widget y el de Siri se perderían uno al otro.
    private var deepLinks: DeepLinkInbox { .shared }

    /// La fase en el tipo propio de `PrivacyGate`, que no depende de SwiftUI
    /// para poder probarse.
    private var privacyPhase: PrivacyGate.ScenePhaseKind {
        switch scenePhase {
        case .active:     .active
        case .inactive:   .inactive
        case .background: .background
        @unknown default: .inactive
        }
    }

    var body: some View {
        Group {
            if !auth.hasRestoredSession {
                LaunchView()
            } else if auth.isAuthenticated {
                DashboardView()
            } else {
                LoginView()
            }
        }
        // Tapada cuando no está activa.
        //
        // La miniatura del conmutador de apps la toma el sistema al salir, y
        // enseñaba la tarjeta con el puesto y la nota a cualquiera que mirara
        // el teléfono. El widget lleva esa disciplina desde el principio; la
        // app no la tenía.
        .overlay {
            if PrivacyGate.shouldCover(phase: privacyPhase) {
                ZStack {
                    Color.paper
                    Image(systemName: "shield.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.brand)
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .accessibilityHidden(true)
            }
        }
        .environment(ticker)
        .environment(deepLinks)
        .task {
            await auth.restoreFromKeychain()
        }
        .onOpenURL { url in
            deepLinks.receive(url)
        }
        .onChange(of: scenePhase) { _, phase in
            ticker.scenePhaseChanged(to: phase)
            // Al volver al frente se refrescan las cifras del widget sin
            // obligar a nadie a entrar en «Mi posición», que hasta ahora era la
            // ÚNICA pantalla que las republicaba: el widget envejecía aunque la
            // persona abriera la app diez veces.
            if phase == .active { Task { await refreshQuickView() } }
        }
    }
}

extension RootView {
    /// Republica la posición del widget con lo último que se sepa.
    ///
    /// Con la vista rápida apagada no pide nada: pedir la posición de alguien
    /// para no publicarla es una petición que no sirve a nadie y toca un dato
    /// que ha dicho que no quiere en su pantalla de inicio. RGPD art. 25.2.
    ///
    /// Un fallo no publica y no borra: la instantánea anterior sigue siendo el
    /// último dato bueno conocido, y el widget ya sabe envejecerla.
    @MainActor
    fileprivate func refreshQuickView() async {
        let publisher = SnapshotPublisher.shared
        guard publisher.shouldRefreshOnForeground(),
              let convocatoriaId = publisher.lastStandingConvocatoriaId,
              auth.isAuthenticated
        else { return }

        do {
            let standing = try await auth.authorized { token in
                try await APIClient.shared.standing(
                    convocatoriaId: convocatoriaId,
                    accessToken: token
                )
            }
            publisher.publish(.posicion(.init(
                convocatoriaName: publisher.lastStandingConvocatoriaName ?? "",
                position: standing.position,
                totalCandidates: standing.totalCandidates,
                score: standing.score,
                attemptsTotal: standing.attemptsTotal,
                finality: GradeFinality(convocatoriaStatus: standing.status).snapshotValue
            )))
        } catch {
            // En silencio a propósito: esto pasa al volver al frente, sin que
            // nadie lo haya pedido, y un aviso por algo que no se solicitó es
            // ruido. Lo que NO se hace es borrar la instantánea buena.
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: 16) {
            // El escudo, como en el acceso: la pantalla de arranque era un
            // indicador del sistema sobre fondo blanco, sin nada del producto,
            // y es lo primero que se ve al abrir.
            Image(systemName: "shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.brand)
                .accessibilityHidden(true)
            ProgressView()
                .controlSize(.large)
                .tint(Color.brand)
            Text(SessionCopy.restoring)
                .font(.metaCaption)
                .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pageBackground()
    }
}

#Preview {
    RootView()
        .environment(AuthSession.previewAuthenticated)
}
