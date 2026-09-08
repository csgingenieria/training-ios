import Foundation

/// Lo que dice cada fila de recorrido bajo su nombre.
///
/// Es la única parte de la pantalla con una decisión dentro, y la decisión es
/// qué NO decir. Tres trampas, y las tres las cae una implementación razonable:
///
/// - La primera vuelta no tiene vuelta anterior. «0,0 menos que la anterior» es
///   aritmética sobre un valor que no existe.
/// - `diffVsScore` se mide contra la nota OFICIAL, así que la fila no puede
///   rotularlo «respecto a su mejor intento»: en el recorrido donde está su
///   mejor intento esa frase es falsa por +4,0.
/// - Un recorrido sin nota no es un recorrido con un cero.
nonisolated enum ProgresoRowCopy {
    /// El subtítulo de la fila.
    static func subtitle(for entrada: ProgressEvolutionDTO) -> String {
        guard entrada.score != nil else {
            // Sin nota no hay tendencia que afirmar, aunque el contrato mande
            // una: la fila dice el hecho y se calla el resto.
            return "Sin nota todavía"
        }

        guard let trend = entrada.trend else {
            // Una tendencia que esta versión no conoce: se enseña la nota y no
            // se inventa la dirección.
            return "Última vuelta"
        }

        switch trend {
        case .primer:
            // Nada que comparar. El hecho es que es la primera.
            return trend.label
        case .estable:
            // La diferencia es cero por definición, y escribir «0,0» junto a
            // «se mantiene» se lee como una pérdida.
            return trend.label
        case .subiendo, .bajando:
            guard let diferencia = diferenciaConLaAnterior(entrada) else { return trend.label }
            return "\(trend.label) \(ScoreFormat.attempt(abs(diferencia))) respecto a la vuelta anterior"
        }
    }

    /// Una sola parada de VoiceOver por fila, con la escala dicha: «8,0» a
    /// secas no dice sobre cuánto, y la fila es un número al lado de un código.
    static func accessibilityLabel(for entrada: ProgressEvolutionDTO) -> String {
        let recorrido = entrada.label ?? entrada.routeCode ?? "Recorrido"
        let nota = entrada.score.map { "\(ScoreFormat.spoken($0, decimals: 1))" }
        return [recorrido, nota, subtitle(for: entrada)]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    /// La diferencia contra la VUELTA ANTERIOR, que es lo que la fila compara.
    ///
    /// **No se usa `diffVsScore`**, que es la diferencia contra la nota oficial
    /// del aspirante y contesta otra pregunta. Mezclarlas es el error que el
    /// backend evitó renombrando el campo, y sería una pena reintroducirlo en
    /// la pantalla.
    private static func diferenciaConLaAnterior(_ entrada: ProgressEvolutionDTO) -> Double? {
        guard let score = entrada.score, let previa = entrada.previousScore else { return nil }
        return score - previa
    }
}
