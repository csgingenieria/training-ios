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
nonisolated enum GradeFinality: Sendable {
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
            // La primera frase es la del portal, y es la que importa: dice que
            // esto todavía no significa nada sobre la persona. La segunda
            // explica por qué puede moverse el número.
            LegalNotice.provisionalHasNoLegalEffect
                + " La convocatoria sigue abierta y esta nota puede variar hasta su cierre."
        case .pendingConfirmation:
            "El acta está firmada. Durante las 24 horas siguientes al cierre aún puede revisarse."
        case .definitive:
            // El silencio se leía como «sigue siendo provisional», que es lo
            // contrario de lo que ocurre con la convocatoria bloqueada.
            "Resultado definitivo al cierre de la convocatoria."
        case .unknown:
            nil
        }
    }

    /// La misma aclaración, con la fecha del cierre cuando se conoce.
    ///
    /// La fecha se añade **solo donde describe un cierre que ya ocurrió**. En
    /// una convocatoria abierta `closedAt` llega `nil` por contrato —no es un
    /// plazo futuro—, así que la nota provisional lo ignora en lugar de
    /// inventarse un «cierra el».
    func note(closedAt: String?) -> String? {
        guard let note else { return nil }
        guard self != .provisional, let fecha = APIDate.shortDate(closedAt) else { return note }
        return "\(note) (\(fecha))"
    }

    /// La finalidad que se puede afirmar teniendo solo la fecha de cierre.
    ///
    /// `/me/progress` y `/me/routes/<code>` no envían el estado de la
    /// convocatoria: solo `closedAt`, documentado como `nil` mientras sigue
    /// abierta. Con eso se deriva el suelo —abierta es provisional, cerrada es
    /// como mucho pendiente de confirmación— y **nunca `.definitive`**, porque
    /// una fecha no distingue `CLOSED` de `LOCKED` y solo `LOCKED` fija la nota.
    init(convocatoriaClosedAt closedAt: String?) {
        let trimmed = (closedAt ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self = trimmed.isEmpty ? .provisional : .pendingConfirmation
    }
}
