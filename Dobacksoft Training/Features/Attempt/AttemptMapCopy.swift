import Foundation

/// Lo que el mapa afirma en palabras.
///
/// Un mapa afirma cosas con la forma de una línea, así que el rótulo de debajo
/// no es adorno: es la diferencia entre una medida y un dibujo. Y todo lo que
/// se dice aquí es sobre el DATO, nunca sobre la conducción — la calidad de una
/// ubicación de GPS no dice nada de cómo condujo nadie.
nonisolated enum AttemptMapCopy {
    /// Qué se está mirando.
    ///
    /// Tres casos, y no son grados del mismo: una traza pegada a la calzada,
    /// una pegada pero con la mitad sin ubicar, y los puntos crudos, que no son
    /// una traza peor sino otra cosa.
    static func traceLabel(_ payload: GpsPayloadDTO) -> String {
        guard let track = payload.track, !track.segments.isEmpty else {
            return "Puntos de GPS sin ajustar: la línea une las posiciones registradas, en el orden en que se registraron."
        }

        if track.isReliable {
            return "Trazado ajustado a la calzada a partir de las posiciones registradas."
        }

        if track.matched == true {
            // Se ajustó, pero con poca parte ubicada. Decir solo «ajustado»
            // presentaría una interpolación como si fuera una medida.
            let ubicado = track.confidence.map { " Se pudo ubicar el \(ScoreFormat.attempt($0 * 100)) % de las posiciones." } ?? ""
            return "Trazado aproximado: parte del recorrido se ha estimado.\(ubicado)"
        }

        return "Puntos de GPS sin ajustar: la línea une las posiciones registradas, en el orden en que se registraron."
    }

    /// Qué significa un corte en la línea.
    ///
    /// Lo que un corte dice es que **el GPS no pudo confirmar ese tramo**, no
    /// que el camión se parara. Son cosas distintas y la segunda sería una
    /// afirmación sobre la vuelta.
    static let gaps =
        "La línea va cortada donde la señal de GPS se perdió: esos tramos no se han podido confirmar."

    /// Dónde vive la respuesta que el mapa no tiene.
    ///
    /// Este endpoint no sabe si un evento restó —no recibe el campo correcto— y
    /// deducirlo aquí haría que el mismo evento se contradijera entre el mapa y
    /// la ficha. Así que no se afirma nada y se dice dónde mirar.
    static let deductionLivesInTheSheet =
        "El desglose de la nota indica cómo se ha tenido en cuenta cada incidencia."

    /// El exceso de velocidad, con los dos números que lo definen.
    static func speeding(excess: Double, limit: Double, speed: Double?) -> String {
        let medida = speed.map { " Velocidad registrada: \(ScoreFormat.attempt($0)) km/h." } ?? ""
        return "Límite de la vía: \(ScoreFormat.attempt(limit)) km/h. Exceso: \(ScoreFormat.attempt(excess)) km/h.\(medida)"
    }

    /// Cómo se nombra un pin en la propia superficie del mapa.
    ///
    /// **Nunca el código del detector.** `EVT_01` no significa nada para nadie,
    /// y el rótulo del pin lo usaba de respaldo mientras el de VoiceOver lo
    /// evitaba con este mismo argumento escrito al lado: quien ve la pantalla
    /// leía un código que a quien la escucha se le ocultaba.
    static func eventTitle(_ event: GpsEventDTO) -> String {
        event.narrative ?? "Incidencia"
    }

    /// La intensidad con la que el SENSOR midió la incidencia.
    ///
    /// No «gravedad de la penalización»: este endpoint no recibe el campo que
    /// dice si el evento restó, así que esa frase iría firmada por un dato que
    /// el mapa no tiene. Lo que se afirma es lo que midió el detector, y dónde
    /// mirar la deducción ya lo dice `deductionLivesInTheSheet`.
    static func intensity(_ intensity: SensorIntensity) -> String {
        "Intensidad medida por el sensor: \(intensity.spoken)."
    }

    /// Lo que VoiceOver dice de un pin.
    ///
    /// Sin el código del detector: `EVT_01` no significa nada para quien
    /// escucha la pantalla, y leerlo en voz alta es ruido con aspecto de dato.
    ///
    /// La intensidad se añade cuando consta, porque es lo único que distingue
    /// un pin de otro: todos se dibujan con el mismo círculo rojo, así que sin
    /// decirla, escuchar el mapa da menos que verlo.
    static func eventLabel(_ event: GpsEventDTO) -> String {
        var partes: [String] = []

        if let narrativa = event.narrative {
            partes.append(narrativa)
        } else if let exceso = event.excessKmh {
            partes.append("Exceso de velocidad de \(ScoreFormat.attempt(exceso)) kilómetros por hora")
        } else {
            partes.append("Incidencia registrada en el recorrido")
        }

        if let intensidad = event.intensity {
            partes.append("intensidad \(intensidad.spoken)")
        }

        return partes.joined(separator: ", ")
    }
}
