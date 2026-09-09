import SwiftUI

/// Cuándo animar, y cuándo no.
///
/// `Theme.motion` existía con sus cinco curvas y se usaba **una sola vez**, en
/// la pulsación de un botón. Todo lo demás era un corte seco: cargando →
/// cargado → error, la cifra del puesto saltando, la lista reordenándose de
/// golpe. Funcionaba y se leía como una recarga de página.
///
/// **Y lo que la auditoría no pedía:** animar sin mirar «Reducir movimiento» es
/// un defecto para quien lo tiene puesto, no un adorno de más. Se activa por
/// sensibilidad vestibular —mareo, vértigo— y en un cuerpo de bomberos hay
/// gente con eso. `.animation` de SwiftUI no lo respeta por su cuenta.
nonisolated enum Motion {
    /// La animación, o **ninguna** si la persona ha pedido reducir el
    /// movimiento.
    ///
    /// `nil` es un valor válido para `.animation(_:value:)` y significa «sin
    /// animación»: el cambio de estado sigue ocurriendo, solo que instantáneo.
    /// Lo que se retira es el movimiento, nunca la información.
    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

extension View {
    /// Anima un cambio de estado respetando «Reducir movimiento».
    func animatedState<V: Equatable>(
        _ value: V,
        _ animation: Animation = Theme.motion.base
    ) -> some View {
        modifier(AnimatedStateModifier(value: value, animation: animation))
    }
}

private struct AnimatedStateModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let value: V
    let animation: Animation

    func body(content: Content) -> some View {
        content.animation(Motion.animation(animation, reduceMotion: reduceMotion), value: value)
    }
}
