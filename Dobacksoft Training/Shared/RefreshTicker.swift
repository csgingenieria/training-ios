import SwiftUI

/// Cuándo volver a pedir los datos porque la persona se fue y ha vuelto.
///
/// Nadie observaba `scenePhase` en toda la app: los datos se cargaban una vez
/// y quien abría la aplicación a la mañana siguiente leía su puesto de ayer sin
/// que nada lo dijera. El widget ya se negaba a mostrar una cifra de seis horas
/// sin etiquetarla (`SnapshotFreshness`); la app no.
///
/// Cuenta generaciones en vez de disparar recargas: así cada pantalla decide
/// con `.task(id:)` si le toca, y una que no esté montada no pide nada. El
/// contador es la señal; recargar es de quien está en pantalla.
@MainActor
@Observable
final class RefreshTicker {
    /// Cuánto tiempo fuera cuenta como haberse ido.
    ///
    /// Cinco minutos. Por debajo, volver es seguir leyendo: recargar tiraría
    /// una pantalla que la persona tenía a medias. Está fijado por un test
    /// para que moverlo sea un acto deliberado y no un ajuste de paso.
    static let staleAfter: TimeInterval = 300

    /// Sube una vez por ausencia larga. Las pantallas la usan como llave.
    private(set) var generation = 0

    /// Cuándo se fue, o `nil` si está aquí.
    private(set) var lastBackgrounded: Date?

    /// El reloj se inyecta para poder probar el umbral con fechas fijas.
    func scenePhaseChanged(to phase: ScenePhase, at now: Date = Date()) {
        switch phase {
        case .background:
            lastBackgrounded = now

        case .active:
            guard let left = lastBackgrounded else { return }
            // Se consume la ausencia en cualquier caso: si no, un reloj que
            // salta atrás dejaría el ticker creyendo que sigue fuera para
            // siempre.
            lastBackgrounded = nil
            let away = now.timeIntervalSince(left)
            // `away >= staleAfter` y no `abs(away)`: un intervalo negativo es
            // un reloj corregido, no cinco minutos fuera.
            guard away >= Self.staleAfter else { return }
            generation += 1

        default:
            // `.inactive` NO es una ausencia: salta con la app todavía en
            // pantalla —un aviso que baja, el conmutador de apps abriéndose—.
            // Contarlo recargaría la pantalla que nadie dejó.
            break
        }
    }
}

/// La llave de recarga de una pantalla que ya recargaba por un identificador.
///
/// Las dos mitades tienen que viajar juntas. Con solo el identificador, volver
/// a la app no recarga nunca; con solo la generación, cambiar de convocatoria
/// no recarga nunca.
struct RefreshKey<ID: Hashable>: Hashable {
    let id: ID
    let generation: Int
}
