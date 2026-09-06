import Foundation

struct AttemptCandidateDTO: Hashable, Sendable {
    let id: String?
    let name: String?
}

nonisolated extension AttemptCandidateDTO: Decodable {}

struct AttemptRouteDTO: Hashable, Sendable {
    let id: String?
    let label: String?
}

nonisolated extension AttemptRouteDTO: Decodable {}

/// Una fila del desglose de la nota de un intento.
///
/// `family` es la ETIQUETA DE DISPLAY que compone el backend («Estabilidad
/// (deducciones)», «Conducción (eventos de Webfleet)»…), no una clave de
/// máquina: una fila medida y otra sin medir del mismo componente comparten
/// etiqueta. Por eso este tipo **no** es `Identifiable` — usar el índice del
/// array como identidad de render.
struct AttemptScoreFamilyDTO: Hashable, Sendable {
    let family: String?
    let obtained: Double?

    /// Peso efectivo del componente por 10. **No es un máximo fijo**: varía por
    /// recorrido desde que existen los pesos por recorrido.
    let max: Double?

    /// Cómo debe representarse la fila.
    ///
    /// Los dos numéricos opcionales codifican tres situaciones distintas, y
    /// pintar «obtenido / máximo» para las tres producía «— / 0» en un
    /// componente que nadie pudo medir. Eso se lee como un cero del aspirante
    /// en un apartado que el tribunal apartó de la nota.
    enum Presentation: Hashable, Sendable {
        /// Hay valor. Un 0 aquí sí es un cero medido.
        case measured(obtained: Double, max: Double)
        /// El componente no puntúa en este recorrido o no pudo evaluarse.
        case notMeasured
        /// El componente puntúa, pero su valor no llegó.
        case missingData

        var label: String {
            switch self {
            case .measured: ""
            case .notMeasured: "No evaluado"
            case .missingData: "Sin dato"
            }
        }
    }

    var presentation: Presentation {
        // Sin peso efectivo el componente no aporta nada a la nota de este
        // recorrido, haya llegado valor o no: pintar «0,0 / 0,0» afirmaría un
        // cero que el aspirante no sacó.
        guard (max ?? 0) > 0 else { return .notMeasured }

        // Con peso, el componente cuenta. Si falta el valor es que no llegó
        // (gates de validez fallados, enriquecimiento pendiente), no que valga
        // cero.
        guard let obtained else { return .missingData }

        return .measured(obtained: obtained, max: max ?? 0)
    }
}

nonisolated extension AttemptScoreFamilyDTO: Decodable {}

struct AttemptEventDTO: Hashable, Sendable, Identifiable {
    let type: String?

    /// Intensidad del canal que disparó el detector.
    ///
    /// **No es una escala continua de 0 a 1**, aunque lo parezca: son tres
    /// cubos derivados de la etiqueta del detector — LEVE 0,3 · MODERADO 0,6 ·
    /// CRÍTICO 0,95, con 0,5 por defecto. Y mide lo que registró el sensor en
    /// mili-g, **no la gravedad con la que se puntuó**: el propio backend lo
    /// advierte por escrito.
    ///
    /// Por eso **nunca** pintar esto como barra, porcentaje o degradado:
    /// afirmaría una resolución que el dato no tiene. Si algún día hay que
    /// mostrarlo, que sea como las tres etiquetas que realmente es.
    ///
    /// Ojo además con un caso que el contrato todavía no distingue: hay eventos
    /// SIEMPRE informativos (badén, acelerón) con deducción 0,0 por diseño que
    /// llegan con `severity > 0` y sin marca alguna. Mostrarlos como incidencia
    /// le atribuye al aspirante una penalización que no existió. Los campos que
    /// lo aclararían (`aplicaANota`, `motivoNoPenaliza`) están pedidos al
    /// backend y hoy se descartan en su remap.
    let severity: Double?

    let confidence: String? // "HIGH" / "LOW"
    let description: String?
    let timestamp: String?
    let source: String?

    var id: String { (type ?? "ev") + "-" + (timestamp ?? UUID().uuidString) }

    /// De dónde salió el evento, en castellano.
    ///
    /// El portal web lo muestra como distintivo junto a cada incidencia, y es
    /// información útil: no pesa lo mismo algo que midió el sensor del camión
    /// que algo que dedujo la telemetría de flota.
    var sourceLabel: String? {
        switch (source ?? "").uppercased() {
        case "DOBACK_ELITE": "Doback Elite"
        case "WEBFLEET":     "Webfleet"
        case "TRAINING":     "Traza propia"
        case "":             nil
        default:             source
        }
    }

    /// Las tres etiquetas reales que hay detrás de `severity`.
    ///
    /// Se reconstruyen desde los cubos del backend (LEVE 0,3 · MODERADO 0,6 ·
    /// CRÍTICO 0,95). Nunca presentar `severity` como escala continua: ver la
    /// nota del campo.
    enum SensorSeverity: String, Sendable {
        case leve = "Leve"
        case moderada = "Moderada"
        case critica = "Crítica"
    }

    var sensorSeverity: SensorSeverity? {
        guard let severity else { return nil }
        switch severity {
        case ..<0.45: return .leve
        case ..<0.8:  return .moderada
        default:      return .critica
        }
    }
}

nonisolated extension AttemptEventDTO: Decodable {}

struct AttemptDetailDTO: Sendable {
    let id: String?
    let candidate: AttemptCandidateDTO?
    let route: AttemptRouteDTO?
    let score: Double?
    let dataQuality: String?

    /// Calidad clasificada. `nil` cuando el backend no la envió o el valor es
    /// desconocido — en ese caso no se pinta insignia.
    var quality: DataQuality? { DataQuality(apiValue: dataQuality) }
    let scoreBreakdown: [AttemptScoreFamilyDTO]
    let events: [AttemptEventDTO]
    let convocatoriaId: String?
}

nonisolated extension AttemptDetailDTO: Decodable {}
