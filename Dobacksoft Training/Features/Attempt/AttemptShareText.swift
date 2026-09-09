import Foundation

/// El texto que sale de la app cuando alguien comparte un intento.
///
/// Vive fuera de la vista porque es lo único de esta pantalla que se puede
/// leer sin la app delante, y porque construido en línea derivó: nombraba el
/// recorrido y la nota pero no CUÁNDO fue el intento, así que dos vueltas al
/// mismo recorrido se compartían como el mismo mensaje.
nonisolated enum AttemptShareText {
    /// El título de la vista previa de la hoja de compartir.
    ///
    /// La hoja enseñaba «Texto» y las primeras palabras del cuerpo, así que dos
    /// intentos seguidos se veían iguales antes de enviarlos. Lo que los separa
    /// es la fecha y el recorrido, en ese orden — la fecha primero por lo mismo
    /// que encabeza el mensaje.
    ///
    /// Nunca queda vacío: una vista previa sin título deja la hoja diciendo
    /// «Texto», que es de donde venimos.
    static func previewTitle(routeLabel: String?, createdAt: String?) -> String {
        // Se descartan las cadenas en blanco, no solo los `nil`: un rótulo
        // vacío dejaba «Intento · » con el separador colgando, que se lee como
        // que falta algo por cargar.
        let partes = [APIDate.shortDateTime(createdAt), routeLabel]
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !partes.isEmpty else { return "Intento" }
        return "Intento · \(partes.joined(separator: " · "))"
    }

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
