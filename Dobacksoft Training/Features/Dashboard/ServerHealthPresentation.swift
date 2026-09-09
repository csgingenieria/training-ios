import Foundation

/// Cómo se presenta el estado del servidor en el perfil.
///
/// La fila metía la frase entera del error en su columna de valor —«No se ha
/// podido conectar. Compruebe su conexión a la red.» en el hueco donde cabe
/// «Disponible»— y `checkHealth()` corría una vez por aparición, sin forma de
/// volver a preguntar.
///
/// Se separa en dos: un valor corto para la fila y el detalle al pie de la
/// sección, que es donde cabe una frase.
nonisolated enum ServerHealthPresentation: Equatable, Sendable {
    case checking
    case available(String)
    case unavailable(String)

    /// Lo que va en la columna de valor. Corto por definición.
    var value: String {
        switch self {
        case .checking:      "Comprobando…"
        case .available:     "Disponible"
        case .unavailable:   "No disponible"
        }
    }

    /// Lo que va al pie, o `nil` si no hay nada que añadir.
    ///
    /// Con el servidor disponible se dice su versión: es el dato que sirve para
    /// cotejar si la app y el backend van a la par cuando algo no cuadra.
    var footer: String? {
        switch self {
        case .checking:                  nil
        case .available(let detalle):    detalle.isEmpty ? nil : detalle
        case .unavailable(let mensaje):  mensaje
        }
    }

    /// Si conviene ofrecer volver a comprobar.
    ///
    /// Mientras comprueba, no: dos peticiones a la vez no aclaran nada.
    var canRecheck: Bool { self != .checking }

    static func from(_ result: Result<HealthDTO, Error>) -> ServerHealthPresentation {
        switch result {
        case .success(let health):
            let detalle = [health.status, health.version]
                .compactMap { APISentinel.text($0) }
                .joined(separator: " · ")
            // `APISentinel` porque el contrato declara los dos como no
            // opcionales pero nada impide que lleguen vacíos, y un « · »
            // suelto al pie se lee como que falta algo.
            return .available(detalle)
        case .failure(let error):
            return .unavailable(
                (error as? APIError)?.userMessage ?? "No disponible."
            )
        }
    }
}
