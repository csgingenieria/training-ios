import Foundation

/// Cómo de viejo es el dato que se va a pintar.
///
/// Anclado siempre en `capturedAt`, nunca en «cuándo se leyó»: un puesto de
/// hace tres días presentado como actual es la misma afirmación falsa que uno
/// inventado, solo que más creíble.
enum SnapshotFreshness: Sendable, Equatable {
    /// Se muestran las cifras sin adorno.
    case fresco
    /// Se muestran las cifras **y** la fecha en que se consultaron.
    case envejecido
    /// Se retiran las cifras: ya no se puede afirmar que sigan siendo ciertas.
    case caducado

    /// A partir de aquí el dato se acompaña de su fecha de consulta.
    static let agingThreshold: TimeInterval = 6 * 3600

    /// A partir de aquí dejan de mostrarse cifras.
    static let expiryThreshold: TimeInterval = 48 * 3600

    /// Evalúa la antigüedad. Función pura: la fecha entra como argumento, nunca
    /// se lee el reloj por dentro.
    static func evaluate(capturedAt: Date, at now: Date) -> SnapshotFreshness {
        let age = now.timeIntervalSince(capturedAt)
        if age >= expiryThreshold { return .caducado }
        if age >= agingThreshold { return .envejecido }
        return .fresco
    }

    /// Instantes futuros en los que la representación cambiaría sola.
    ///
    /// El proveedor de la línea temporal los usa para programar entradas sin
    /// gastar presupuesto de recarga: con una sola lectura de fichero deja
    /// preparado el envejecimiento del dato. Devuelve solo los cruces
    /// posteriores a `now`, en orden.
    static func futureThresholdCrossings(capturedAt: Date, after now: Date) -> [Date] {
        [
            capturedAt.addingTimeInterval(agingThreshold),
            capturedAt.addingTimeInterval(expiryThreshold),
        ]
        .filter { $0 > now }
        .sorted()
    }
}
