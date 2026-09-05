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
        guard let obtained else {
            // Sin peso efectivo el componente no entra en la nota de este
            // recorrido; con peso, entra pero falta el dato.
            return (max ?? 0) > 0 ? .missingData : .notMeasured
        }
        return .measured(obtained: obtained, max: max ?? 0)
    }
}

nonisolated extension AttemptScoreFamilyDTO: Decodable {}

struct AttemptEventDTO: Hashable, Sendable, Identifiable {
    let type: String?
    let severity: Double?  // backend devuelve 0..1
    let confidence: String? // "HIGH" / "LOW"
    let description: String?
    let timestamp: String?
    let source: String?

    var id: String { (type ?? "ev") + "-" + (timestamp ?? UUID().uuidString) }
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
