import Foundation

/// El subtítulo del saludo en «Mi posición».
///
/// Era una cuenta —«1 convocatoria activa»— que en el caso común (una sola, sin
/// fila de chips, porque los chips aparecen a partir de dos) no le decía al
/// aspirante nada que no estuviera viendo. El portal escribe en su lugar el
/// nombre y la fecha, que son los dos datos que sitúan todo lo de abajo.
///
/// Y la cuenta estaba mal por dos lados: contaba todas las inscripciones,
/// cerradas incluidas, mientras las llamaba «activas».
///
/// Vive fuera de la vista para poder probarlo: una cuenta con una palabra que
/// no describe lo que cuenta es exactamente el defecto que un test caza y una
/// lectura por encima no.
nonisolated enum StandingHeaderCopy {
    static func subtitle(
        selected: ConvocatoriaSummaryDTO?,
        convocatorias: [ConvocatoriaSummaryDTO]
    ) -> String {
        if let named = name(of: selected) {
            return named
        }
        return countSentence(inCourse(convocatorias).count)
    }

    /// El nombre de la convocatoria elegida, con su fecha de cierre si la tiene.
    ///
    /// «Cerrada el» y no «Cierra el»: `closedAt` es cuándo se CERRÓ, no un
    /// plazo. Rotularlo en futuro prometería una fecha que el contrato no
    /// envía. Una marca de tiempo que no se puede leer se descarta — un
    /// rótulo sin nada detrás se lee como un fallo.
    private static func name(of convocatoria: ConvocatoriaSummaryDTO?) -> String? {
        guard let convocatoria else { return nil }
        let name = convocatoria.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        guard let closed = APIDate.shortDate(convocatoria.closedAt) else { return name }
        return "\(name) · Cerrada el \(closed)"
    }

    /// Las que siguen en curso, con el mismo criterio que el filtro de la
    /// pantalla de convocatorias. Dos criterios para un mismo estado es cómo
    /// se acaba con dos pantallas que no dicen lo mismo.
    private static func inCourse(
        _ convocatorias: [ConvocatoriaSummaryDTO]
    ) -> [ConvocatoriaSummaryDTO] {
        convocatorias.filter(ConvocatoriaScope.activas.matches)
    }

    /// «en curso» y no «activas», por lo mismo: es la palabra que ya usa ese
    /// filtro, y dos palabras para un estado dejan al aspirante preguntándose
    /// si son cosas distintas.
    private static func countSentence(_ count: Int) -> String {
        let estado = ConvocatoriaScope.activas.title.lowercased()
        switch count {
        case 0:  return "Sin convocatorias \(estado)"
        case 1:  return "1 convocatoria \(estado)"
        default: return "\(count) convocatorias \(estado)"
        }
    }
}
