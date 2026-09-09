import Foundation

/// En qué fase está una pantalla, sin el dato dentro.
///
/// Existe para poder animar el cambio sin exigir `Equatable` a los DTO. Animar
/// sobre el estado completo obligaría a que cada respuesta del backend fuera
/// comparable —trabajo real y sin más motivo que este— y además volvería a
/// animar cuando cambia solo una cifra dentro de la fase cargada, que es cosa
/// de `contentTransition` y no de una transición de pantalla.
///
/// Cuatro fases y no cinco: `notFound` y `empty` se animan igual porque las dos
/// son «no hay nada que enseñar aquí». La distinción entre ellas importa en lo
/// que se DICE, no en cómo aparece, y eso ya lo separan los estados.
nonisolated enum ScreenPhase: Equatable, Sendable {
    case loading
    case loaded
    case empty
    case error
    /// El dato guardado, cuando no hay red.
    case cached
}
