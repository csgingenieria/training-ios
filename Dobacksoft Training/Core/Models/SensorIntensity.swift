import Foundation

/// Con qué intensidad midió el sensor una incidencia.
///
/// **Una sola regla para los dos endpoints que la envían.** La ficha
/// (`/attempts/<id>`) y el mapa (`/attempts/<id>/gps`) describen los mismos
/// eventos, y hasta hace poco no coincidían: el mapa llamaba `severity` a lo
/// que la ficha llama `sensorSeverity`. El backend lo unificó de su lado; si
/// aquí cada DTO deriva la intensidad por su cuenta, la misma incidencia puede
/// volver a leerse distinta según por dónde se abra, y esta vez sin que nada
/// se caiga para avisar.
nonisolated enum SensorIntensity: String, Sendable, CaseIterable {
    case leve = "Leve"
    case moderada = "Moderada"
    case critica = "Crítica"

    /// La etiqueta es la fuente preferente; el número, el respaldo.
    ///
    /// El número venía en cubos (LEVE 0,3 · MODERADO 0,6 · CRÍTICO 0,95) con un
    /// centinela **0,5 para «no se supo clasificar»**, que reconstruido caía en
    /// «moderada»: una intensidad que nadie midió. Por eso 0,5 no devuelve
    /// nada, y por eso la etiqueta manda cuando está.
    ///
    /// Una etiqueta que no reconocemos tampoco se traduce a ojo: se pasa al
    /// número, y si tampoco está, no se afirma nada.
    static func derived(label: String?, number: Double?) -> SensorIntensity? {
        switch (label ?? "").uppercased() {
        case "LEVE":     return .leve
        case "MODERADO": return .moderada
        case "CRITICO":  return .critica
        default: break
        }

        guard let number, number != 0.5 else { return nil }
        switch number {
        case ..<0.45: return .leve
        case ..<0.8:  return .moderada
        default:      return .critica
        }
    }

    /// Cómo se nombra en una frase.
    var spoken: String { rawValue.lowercased() }
}
