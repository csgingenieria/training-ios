import Foundation

/// Por qué el backend respondió 404.
///
/// Los tres 404 del standing compartían código y solo se distinguían por el
/// texto castellano del mensaje, que es interfaz y no contrato. Ahora llegan
/// diferenciados, y la diferencia importa: **dos de los tres no son errores**.
///
/// No estar inscrito es un hecho. No tener posición todavía es el estado normal
/// de todo el mundo al abrir una convocatoria, antes de conducir. Enseñar una
/// pantalla de error para eso le dice a un aspirante que algo ha fallado cuando
/// no ha fallado nada.
enum NotFoundReason: Sendable, Equatable {
    /// No consta su inscripción en esa convocatoria.
    case notEnrolled
    /// Inscrito, pero todavía sin ningún recorrido calificado.
    case noStandingYet
    /// El recurso no existe. El único de los tres que es un fallo.
    case resourceMissing

    /// Construye desde la clave `error` del cuerpo de la respuesta.
    ///
    /// **Es `error`, no `code`.** Y hay seis endpoints más que reutilizan
    /// `not_found` genérico, así que lo desconocido cae ahí sin adivinar.
    init(apiCode: String?) {
        switch (apiCode ?? "").trimmingCharacters(in: .whitespaces) {
        case "not_enrolled":    self = .notEnrolled
        case "no_standing_yet": self = .noStandingYet
        default:                self = .resourceMissing
        }
    }

    /// `true` solo cuando de verdad ha ido algo mal.
    var isFailure: Bool { self == .resourceMissing }

    var title: String {
        switch self {
        case .notEnrolled:     "Sin inscripción"
        case .noStandingYet:   "Todavía sin posición"
        case .resourceMissing: "No encontrado"
        }
    }

    var detail: String {
        switch self {
        case .notEnrolled:
            "No consta su inscripción en esta convocatoria."
        case .noStandingYet:
            "Su posición aparecerá cuando se registre el primer recorrido calificado."
        case .resourceMissing:
            "No se ha encontrado el recurso solicitado."
        }
    }

    /// Símbolo acorde al tono: los dos estados legítimos no llevan iconografía
    /// de error.
    var symbol: String {
        switch self {
        case .notEnrolled:     "person.crop.circle.badge.questionmark"
        case .noStandingYet:   "hourglass"
        case .resourceMissing: "questionmark.folder"
        }
    }
}
