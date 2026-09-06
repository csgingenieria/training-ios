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
    /// La convocatoria sigue abierta: la nota puede cambiar por conducción.
    case provisional
    /// El acta está firmada pero sigue dentro de la ventana de revocación.
    case pendingConfirmation
    /// La nota ya no puede cambiar.
    case definitive
    /// No se conoce el estado de la convocatoria: no se afirma nada.
    case unknown

    init(convocatoriaStatus: String?) {
        let normalised = (convocatoriaStatus ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        switch normalised {
        case "LOCKED":
            // Único estado en el que la nota es realmente inamovible.
            self = .definitive
        case "CLOSED":
            // Acta firmada, pero el administrador dispone de 24 horas para
            // revertir el cierre por error grave. Llamar «definitiva» a una
            // nota que aún puede moverse es afirmar de más sobre una persona
            // en una oposición pública.
            self = .pendingConfirmation
        case "OPEN", "PREVIEW", "CLOSING":
            // CLOSING es un cierre iniciado y no consumado: sigue abierta.
            self = .provisional
        default:
            // Un estado que no reconocemos no autoriza a afirmar nada. Elegir
            // por defecto sería inventarse el dato en una u otra dirección.
            self = .unknown
        }
    }

    /// Rótulo de la métrica de nota.
    var scoreLabel: String {
        switch self {
        case .provisional:          "Nota provisional"
        case .pendingConfirmation:  "Nota pendiente de confirmación"
        case .definitive, .unknown: "Nota"
        }
    }

    /// Aclaración mostrada bajo la nota, o `nil` si no hay nada que aclarar.
    var note: String? {
        switch self {
        case .provisional:
            "La convocatoria sigue abierta: esta nota puede variar hasta su cierre."
        case .pendingConfirmation:
            "El acta está firmada. Durante las 24 horas siguientes al cierre aún puede revisarse."
        case .definitive, .unknown:
            nil
        }
    }
}
