import Foundation
import CoreLocation

/// `GET /api/v1/attempts/<id>/gps` — la traza de la vuelta.
///
/// Lo que hace de esto un contrato delicado es que **se dibuja**: un mapa
/// afirma cosas con la forma de una línea, y una línea de más es una vuelta
/// que nadie condujo.
struct GpsPayloadDTO: Sendable {
    /// Los puntos crudos. **Respaldo**, no la traza: solo se dibujan cuando no
    /// hay nada pegado a la calzada.
    let points: [GpsPointDTO]

    /// Los waypoints del recorrido previsto, para contrastar.
    let route: [GpsCoordinateDTO]

    let events: [GpsEventDTO]

    /// La traza buena. Ver `GpsTrackDTO`.
    let track: GpsTrackDTO?

    /// Lo que hay que dibujar, en el orden correcto de preferencia.
    ///
    /// La traza pegada a la calzada gana. Dibujar los puntos crudos encima de
    /// una traza ajustada enseñaría una línea peor que la disponible.
    var drawableSegments: [[GpsCoordinateDTO]] {
        if let segmentos = track?.segments, !segmentos.isEmpty { return segmentos }
        let crudos = points.compactMap(\.coordinate)
        return crudos.isEmpty ? [] : [crudos]
    }

    /// Si lo que se dibuja son los puntos crudos y no la traza ajustada.
    ///
    /// La pantalla lo rotula: leer una aproximación como una medida es el error
    /// que un mapa sin etiqueta invita a cometer.
    var isFallback: Bool {
        (track?.segments.isEmpty ?? true) && !points.isEmpty
    }

    var hasSomethingToDraw: Bool { !drawableSegments.isEmpty }

    /// Los eventos que se pueden clavar en el mapa.
    ///
    /// Uno sin coordenadas no se coloca en ningún sitio: inventarle un lugar
    /// pondría una incidencia donde no ocurrió.
    var pinnableEvents: [GpsEventDTO] { events.filter { $0.coordinate != nil } }

    /// Las identidades para cruzar con la ficha.
    ///
    /// Es lo único que el mapa aporta sobre si un evento restó: **este endpoint
    /// no lo dice**, porque no tiene la fuente correcta (`descuenta`).
    /// Derivarlo aquí haría que el mismo evento se contradijera entre el mapa y
    /// la ficha.
    var crossReferenceIds: [String] { events.compactMap(\.id) }
}

nonisolated extension GpsPayloadDTO: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            points: try c.decodeIfPresent([GpsPointDTO].self, forKey: .points) ?? [],
            route: try c.decodeIfPresent([GpsCoordinateDTO].self, forKey: .route) ?? [],
            events: try c.decodeIfPresent([GpsEventDTO].self, forKey: .events) ?? [],
            track: try c.decodeIfPresent(GpsTrackDTO.self, forKey: .track)
        )
    }

    private enum CodingKeys: String, CodingKey { case points, route, events, track }
}

// MARK: - La traza

/// La traza de la vuelta, en segmentos.
///
/// **Es un diccionario con `segments`, no una lista de puntos**, y esa forma es
/// el dato: más de un segmento significa que el GPS dio un salto imposible y la
/// línea se cortó **a propósito**. Unirlos dibujaría al camión atravesando un
/// terreno que nunca atravesó.
struct GpsTrackDTO: Sendable {
    /// Las polilíneas. Un corte entre dos es un salto que no se puede afirmar.
    let segments: [[GpsCoordinateDTO]]

    /// Si está pegada a la calzada.
    let matched: Bool?

    /// Qué fracción de los puntos se pudo ubicar. La pantalla lo rotula para
    /// que se vea QUÉ se está mirando.
    let confidence: Double?

    let source: String?

    /// Si hubo saltos imposibles y la línea va cortada.
    var hasGaps: Bool { segments.count > 1 }

    /// Si la traza se puede presentar como una medida y no como un dibujo
    /// aproximado.
    ///
    /// Exige las dos cosas: pegada a la calzada **y** con más de la mitad de
    /// los puntos ubicados. Sin pegar no hay nada que afirmar, y con la mitad
    /// sin ubicar la línea es una interpolación con aspecto de medida.
    var isReliable: Bool {
        matched == true && (confidence ?? 0) > 0.5
    }
}

nonisolated extension GpsTrackDTO: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Los segmentos llegan como pares `[lat, lng]`. Un par roto se descarta
        // en vez de tumbar la traza: perder un punto es recuperable, perder la
        // vuelta entera por un punto no.
        //
        // Y con `try?`: si la FORMA entera del array sorprende —una coordenada
        // como texto, un nivel de anidamiento de más—, se pierde la traza
        // ajustada y el mapa cae a los puntos crudos, que es el respaldo que ya
        // tiene diseñado. Con `try` a secas se perdía el payload completo: ni
        // traza, ni puntos, ni eventos, ni recorrido.
        let crudos = (try? c.decodeIfPresent([[[Double]]].self, forKey: .segments)) ?? []
        self.init(
            segments: crudos.map { segmento in
                segmento.compactMap { par in
                    par.count == 2 ? GpsCoordinateDTO(lat: par[0], lng: par[1]) : nil
                }
            },
            // Tolerantes por lo mismo que en el punto y en el evento: ninguna
            // de estas tres cifras vale el mapa entero. `confidence` fue
            // justamente el campo que resultó tener otro tipo del declarado.
            matched: c.lenientBool(forKey: .matched),
            confidence: c.lenientDouble(forKey: .confidence),
            source: c.lenientString(forKey: .source)
        )
    }

    private enum CodingKeys: String, CodingKey { case segments, matched, confidence, source }
}

// MARK: - Coordenadas y puntos

struct GpsCoordinateDTO: Sendable, Hashable {
    let lat: Double
    let lng: Double

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

nonisolated extension GpsCoordinateDTO: Decodable {}

/// Un punto crudo de la traza, con lo que el receptor supo de él.
struct GpsPointDTO: Sendable, Hashable {
    let lat: Double?
    let lng: Double?
    let speed: Double?

    /// Cuánta confianza tiene el punto, de 0 a 1.
    ///
    /// **Estaba declarado `String?` y es un número.** No a veces: nunca llegó
    /// como texto. En las once vueltas del aspirante de staging son 4.685
    /// puntos con `null` y 381 con `0.9`, y ni uno con una cadena. Un
    /// `decodeIfPresent(String.self)` sobre `0.9` lanza, y como el DTO se
    /// decodificaba de forma estricta, un punto entre cinco mil **hundía el
    /// mapa entero**: los once de once.
    ///
    /// **Se decodifica, y no se usa para decidir nada.** Medido contra la base
    /// del VPS sobre 23.644 puntos de intentos cerrados: 23.209 nulos y 435 con
    /// valor, y ese valor es `0.9` **siempre** —un único valor distinto—. No es
    /// una medida de confianza: es una constante que alguien puso. Pintarla, o
    /// filtrar puntos por ella, sería presentar un adorno como un dato.
    ///
    /// Opcional, y por eso no muerde: si fuera `Double` a secas fallaría en el
    /// 98,2 % de los puntos, no en un caso raro.
    ///
    /// Comparte nombre con `GpsTrackDTO.confidence` (número, de verdad medido)
    /// y con `AttemptEventDTO.confidence` (texto, `"HIGH"`/`"LOW"`). Los tres
    /// se llaman igual y no son lo mismo.
    let confidence: Double?

    let source: String?

    var coordinate: GpsCoordinateDTO? {
        guard let lat, let lng else { return nil }
        return GpsCoordinateDTO(lat: lat, lng: lng)
    }
}

nonisolated extension GpsPointDTO: Decodable {
    /// Lectura tolerante, por la misma razón que en los eventos.
    ///
    /// La regla ya estaba escrita para `GpsEventDTO` —«un tipo inesperado no
    /// puede hundir la respuesta»— y `points` se quedó fuera. Ahí estuvo el
    /// defecto: la disciplina existía, aplicada a un array de los cuatro.
    ///
    /// Las coordenadas también se leen tolerantes: sin ellas el punto no se
    /// coloca, y un punto que no se coloca vale infinitamente más que un mapa
    /// que no se dibuja.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            lat: c.lenientDouble(forKey: .lat),
            lng: c.lenientDouble(forKey: .lng),
            speed: c.lenientDouble(forKey: .speed),
            confidence: c.lenientDouble(forKey: .confidence),
            source: c.lenientString(forKey: .source)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case lat, lng, speed, confidence, source
    }
}

// MARK: - Eventos sobre el mapa

/// Un evento con su sitio en el mapa.
///
/// **Sin `affectsScore`, y es deliberado.** Este endpoint no tiene la fuente
/// correcta para decir si el evento restó, y emitirlo desde `aplica_a_nota`
/// haría que el mismo evento se contradijera entre el mapa y la ficha. El
/// cliente lo cruza por `id` con `/attempts/<id>`.
struct GpsEventDTO: Sendable, Hashable, Identifiable {
    let id: String?
    let type: String?
    let severity: Double?

    /// La etiqueta del sensor (`LEVE`, `MODERADO`, `CRITICO`).
    ///
    /// Llegaba y se tiraba. El mapa mandaba **solo la etiqueta con el nombre
    /// del número** —`severity: "CRITICO"`— y eso hundía el payload entero; al
    /// arreglarlo, el backend pasó a mandar las dos con los mismos nombres que
    /// la ficha, y el cliente se quedó decodificando una sola.
    ///
    /// Es el patrón que este repo repite: el campo llega, alguien lo arregla al
    /// otro lado, y aquí sigue sin leerse. El defecto anterior era ruidoso —la
    /// pantalla se caía—; este es silencioso.
    let sensorSeverity: String?

    let source: String?
    let timestamp: String?

    let lat: Double?
    let lng: Double?

    /// La gravedad que le puso el DETECTOR, no necesariamente lo que restó.
    let penaltyPoints: Double?
    let noPenaltyReason: String?
    let stabilityLossPercent: Double?

    /// La explicación y el consejo los escribe el backend; se pintan tal cual.
    let narrative: String?
    let advice: String?

    let speedKmh: Double?
    let limitKmh: Double?
    let excessKmh: Double?

    /// Con qué intensidad midió el sensor, por la MISMA regla que la ficha.
    ///
    /// Sin esto el mapa se callaba una intensidad que la ficha sí decía del
    /// mismo evento, y quien abría la incidencia desde el mapa veía menos que
    /// quien la abría desde el desglose.
    var intensity: SensorIntensity? {
        SensorIntensity.derived(label: sensorSeverity, number: severity)
    }

    /// Dónde ocurrió, o `nil` si no consta.
    var coordinate: GpsCoordinateDTO? {
        guard let lat, let lng else { return nil }
        return GpsCoordinateDTO(lat: lat, lng: lng)
    }
}

nonisolated extension GpsEventDTO: Decodable {
    /// Lectura tolerante en todo lo que no es estructural.
    ///
    /// El `id` y las coordenadas sí son estructurales —sin identidad no hay
    /// cruce con la ficha, y sin coordenadas el evento no se coloca— pero
    /// llegan como opcionales y su ausencia ya está prevista. Lo demás es
    /// comentario sobre el evento, y ninguna de esas cifras vale el mapa
    /// entero: `severity` llegaba como TEXTO desde este endpoint y hundía el
    /// trazado completo de la vuelta.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: APISentinel.text(c.lenientString(forKey: .id)),
            type: c.lenientString(forKey: .type),
            severity: c.lenientDouble(forKey: .severity),
            sensorSeverity: c.lenientLabel(forKey: .sensorSeverity),
            source: c.lenientString(forKey: .source),
            timestamp: c.lenientString(forKey: .timestamp),
            lat: c.lenientDouble(forKey: .lat),
            lng: c.lenientDouble(forKey: .lng),
            penaltyPoints: c.lenientDouble(forKey: .penaltyPoints),
            noPenaltyReason: c.lenientString(forKey: .noPenaltyReason),
            stabilityLossPercent: c.lenientDouble(forKey: .stabilityLossPercent),
            narrative: c.lenientString(forKey: .narrative),
            advice: c.lenientString(forKey: .advice),
            speedKmh: c.lenientDouble(forKey: .speedKmh),
            limitKmh: c.lenientDouble(forKey: .limitKmh),
            excessKmh: c.lenientDouble(forKey: .excessKmh)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, severity, sensorSeverity, source, timestamp, lat, lng
        case penaltyPoints, noPenaltyReason, stabilityLossPercent
        case narrative, advice, speedKmh, limitKmh, excessKmh
    }
}
