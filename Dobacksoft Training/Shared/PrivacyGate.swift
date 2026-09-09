import Foundation

/// Cuándo hay que tapar lo que la pantalla enseña.
///
/// El widget es de privacidad primero —apagado por defecto citando el RGPD
/// art. 25.2, cifras marcadas `.privacySensitive()`— y la app abría directa en
/// el puesto y la nota, con la miniatura del conmutador de apps enseñando la
/// tarjeta. Nadie observaba `scenePhase` para eso.
///
/// La miniatura es el caso que más importa y el más barato: la genera el
/// sistema al salir de la app y se ve en el conmutador, que es donde alguien
/// mira el teléfono de otro sin desbloquearlo.
nonisolated enum PrivacyGate {
    /// Si la app debe taparse en esta fase.
    ///
    /// Todo lo que no sea `.active`: `.inactive` es justo cuando el sistema
    /// toma la miniatura, así que esperar a `.background` la sacaría con las
    /// cifras dentro.
    static func shouldCover(phase: ScenePhaseKind) -> Bool {
        phase != .active
    }

    /// Fase, en un tipo propio para poder probarlo sin SwiftUI.
    enum ScenePhaseKind: Sendable, Equatable {
        case active
        case inactive
        case background
    }
}
