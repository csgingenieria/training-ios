import Foundation

/// Si la nota que se muestra es definitiva o todavía puede cambiar.
///
/// El sistema distingue nota provisional de definitiva por el estado de la
/// **convocatoria**: solo es definitiva con la convocatoria cerrada o bloqueada
/// (`_ESTADOS_NOTA_DEFINITIVA` en `student_service.py:767-775`). El portal web
/// ya lo dice; la app no lo decía en ninguna pantalla.
///
/// Importa más de lo que parece: la nota oficial es la media sobre los
/// recorridos exigidos, contando 0 los no conducidos. Si el tribunal retira del
/// conjunto exigido un recorrido que nunca hizo conducible, la nota sube sola,
/// sin desplegar nada. Presentar eso como definitivo es afirmar algo falso
/// sobre una persona en una oposición pública.
///
/// **No derivar esto de `StandingDTO.status`**: ese campo es el estado de la
/// MATRÍCULA del aspirante (`enrollment.status`), no el de la convocatoria.
///
/// Cuando el backend publique `gradeIsFinal`, este tipo es el único sitio a
/// cambiar.
enum GradeFinality: Sendable {
    case provisional
    case definitive
    /// No se conoce el estado de la convocatoria: no se afirma nada.
    case unknown

    /// Estados de convocatoria en los que la nota ya no cambia.
    private static let finalStates: Set<String> = ["CLOSED", "LOCKED"]

    /// Estados en los que la nota todavía puede moverse.
    private static let openStates: Set<String> = ["OPEN", "PREVIEW", "CLOSING"]

    init(convocatoriaStatus: String?) {
        let normalised = (convocatoriaStatus ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if Self.finalStates.contains(normalised) {
            self = .definitive
        } else if Self.openStates.contains(normalised) {
            self = .provisional
        } else {
            // Un estado que no reconocemos no autoriza a afirmar nada. Elegir
            // por defecto sería inventarse el dato en una u otra dirección.
            self = .unknown
        }
    }

    /// Rótulo de la métrica de nota.
    var scoreLabel: String {
        switch self {
        case .provisional: "Nota provisional"
        case .definitive, .unknown: "Nota"
        }
    }

    /// Aclaración mostrada bajo la nota, o `nil` si no hay nada que aclarar.
    var note: String? {
        switch self {
        case .provisional:
            "La convocatoria sigue abierta: esta nota puede variar hasta su cierre."
        case .definitive, .unknown:
            nil
        }
    }
}
