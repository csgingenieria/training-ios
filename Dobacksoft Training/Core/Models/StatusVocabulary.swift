import Foundation

/// Cómo se enseña un estado del backend en una pantalla en castellano.
///
/// Hasta ahora las insignias pintaban el valor crudo: un aspirante veía
/// «ACTIVE» bajo «Estado de su matrícula» y «OPEN» sobre su convocatoria, en
/// una interfaz que por lo demás le trata de usted en castellano formal. El
/// lector es un bombero de la Comunidad de Madrid consultando un proceso
/// oficial, no alguien depurando una API.
///
/// El color ya se decidía en cuatro `badgeKind(for:)` privados —dos parejas
/// idénticas copiadas entre vistas—, así que rótulo y color viven aquí juntos:
/// separarlos garantizaba que se desincronizasen.
///
/// **Un estado desconocido se muestra tal cual llega.** No se traduce a
/// «Desconocido» ni se oculta: si mañana el backend publica un estado nuevo,
/// que el usuario vea el código es recuperable; que la app se lo trague, no.
nonisolated struct StatusPresentation: Equatable, Sendable {
    let label: String
    let kind: BadgeKind
}

nonisolated enum StatusVocabulary {
    /// Estado de la MATRÍCULA del aspirante (`enrollment.status`).
    ///
    /// Ojo: no es el estado de la convocatoria. Derivar de aquí si la nota es
    /// definitiva sería un error — para eso está `GradeFinality`.
    static func enrolment(_ raw: String?) -> StatusPresentation {
        switch normalise(raw) {
        case "ACTIVE", "ACTIVA":
            StatusPresentation(label: "Activa", kind: .success)
        case "WITHDRAWN", "BAJA":
            StatusPresentation(label: "Baja", kind: .danger)
        case "INVALIDATED":
            StatusPresentation(label: "Anulada", kind: .danger)
        default:
            unrecognised(raw)
        }
    }

    /// Estado de la CONVOCATORIA.
    ///
    /// El vocabulario sigue el mismo eje que `GradeFinality`: `CLOSED` es el
    /// acta firmada con la ventana de revocación abierta, y solo `LOCKED` es
    /// inamovible. Por eso son dos rótulos distintos y no uno.
    static func convocatoria(_ raw: String?) -> StatusPresentation {
        switch normalise(raw) {
        case "OPEN", "ACTIVE", "ACTIVA", "EN CURSO":
            StatusPresentation(label: "Abierta", kind: .success)
        case "CLOSING":
            StatusPresentation(label: "En cierre", kind: .warning)
        case "CLOSED", "CERRADA":
            StatusPresentation(label: "Cerrada", kind: .neutral)
        case "LOCKED":
            StatusPresentation(label: "Definitiva", kind: .neutral)
        case "PREVIEW":
            StatusPresentation(label: "Previa", kind: .warning)
        case "DRAFT", "BORRADOR":
            StatusPresentation(label: "Borrador", kind: .warning)
        case "ARCHIVED":
            StatusPresentation(label: "Archivada", kind: .neutral)
        default:
            unrecognised(raw)
        }
    }

    // MARK: -

    private static func normalise(_ raw: String?) -> String {
        (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// Un estado que esta versión no conoce se enseña literal y sin color.
    /// Vacío es lo único que no puede enseñarse: dejaría una cápsula muda.
    private static func unrecognised(_ raw: String?) -> StatusPresentation {
        let normalised = normalise(raw)
        return StatusPresentation(
            label: normalised.isEmpty ? "Sin estado" : normalised,
            kind: .neutral
        )
    }
}
