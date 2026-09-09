import Foundation

/// El texto que sale de la app al compartir una convocatoria.
///
/// Se construía en línea dentro del detalle, y por eso emitía **el estado en
/// crudo del backend**: «Estado: OPEN». Es el mismo defecto que el «Calidad:
/// HIGH» del intento, en otra pantalla y sin que nadie lo notara — la señal de
/// que una copia construida a mano en una vista deriva sola.
nonisolated enum ConvocatoriaShareText {
    static func build(_ convocatoria: ConvocatoriaSummaryDTO) -> String {
        var lines = ["Convocatoria Training · CMadrid", convocatoria.name]

        // El rótulo, no el código: «Abierta», no «OPEN».
        if let status = APISentinel.text(convocatoria.status) {
            lines.append("Estado: \(StatusVocabulary.convocatoria(status).label)")
        }

        lines.append(
            convocatoria.totalCandidates == 1
                ? "1 aspirante"
                : "\(convocatoria.totalCandidates) aspirantes"
        )

        // La fecha en pasado, que es lo que el campo dice.
        if let cerrada = APIDate.shortDate(convocatoria.closedAt) {
            lines.append("Cerrada el \(cerrada)")
        }

        return lines.joined(separator: "\n")
    }
}
