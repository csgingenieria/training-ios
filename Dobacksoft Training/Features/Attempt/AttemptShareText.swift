import Foundation

/// El texto que sale de la app cuando alguien comparte un intento.
///
/// Vive fuera de la vista porque es lo único de esta pantalla que se puede
/// leer sin la app delante, y porque construido en línea derivó: nombraba el
/// recorrido y la nota pero no CUÁNDO fue el intento, así que dos vueltas al
/// mismo recorrido se compartían como el mismo mensaje.
nonisolated enum AttemptShareText {
    static func build(
        candidateName: String?,
        routeLabel: String?,
        score: Double?,
        quality: DataQuality?,
        createdAt: String?
    ) -> String {
        var lines = ["Intento Training · CMadrid"]

        // La fecha va primero: es lo que distingue una vuelta de la siguiente,
        // y sin ella el mensaje no se puede situar. Solo cuando se puede leer
        // —una marca de tiempo que no parsea se calla, en lugar de sacar un
        // ISO 8601 en crudo a una conversación.
        if let fecha = APIDate.shortDateTime(createdAt) {
            lines.append("Fecha: \(fecha)")
        }

        // «Aspirante», no «Alumno». Era el último sitio donde sobrevivía esa
        // palabra, y justo el que se lee fuera.
        if let candidateName {
            lines.append("Aspirante: \(candidateName)")
        }
        if let routeLabel {
            lines.append("Recorrido: \(routeLabel)")
        }
        if let score {
            // Con la escala: un «8,5» suelto en un chat no dice sobre cuánto.
            lines.append("Nota: \(ScoreFormat.attempt(score))/10")
        }
        if let quality {
            // La frase, no el código del API: se compartía «Calidad: HIGH».
            lines.append(quality.label)
        }

        return lines.joined(separator: "\n")
    }
}
