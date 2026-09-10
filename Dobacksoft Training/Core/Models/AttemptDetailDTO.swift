import Foundation

struct AttemptCandidateDTO: Hashable, Sendable {
    let id: String?
    let name: String?
}

nonisolated extension AttemptCandidateDTO: Decodable {}

/// El recorrido de un intento.
///
/// `id` y `label` son AMBOS el código crudo del recorrido («2A1»). El nombre
/// legible («Parque → Hoyo de Manzanares») viaja aparte en `name`, y el
/// contrato es así por historia: en la matriz, en cambio, `label` sí trae el
/// nombre. No confiar en `label` para mostrar al usuario.
struct AttemptRouteDTO: Hashable, Sendable {
    let id: String?
    let label: String?

    /// Nombre legible. **Nulable**: vale `nil` si el intento no tiene recorrido
    /// asignado o si la fila del recorrido no aparece. Y sí, existen intentos
    /// sin recorrido en producción, con nota.
    let name: String?

    /// `EXAMEN` o `PRACTICA`. **Nulable** por el mismo motivo que `name`.
    let categoria: String?

    /// Si el recorrido sigue en el catálogo. **Tres estados, no dos.**
    ///
    /// `nil` cuando no hay fila `Route` —intentos sin recorrido, que existen
    /// en producción con nota, y códigos huérfanos de un catálogo borrado—.
    /// No se colapsa a `false`: eso afirmaría que se retiró, y `true` que
    /// sigue ofreciéndose, cuando lo que pasa es que no se sabe.
    ///
    /// Es la señal con la que la web decide si ofrecer el enlace a la ficha
    /// del recorrido, y **no se puede deducir de los metadatos**: `distanceKm`
    /// y `durationMin` llegan igual para un recorrido retirado, porque el
    /// intento ya se condujo y que el recorrido no se ofrezca más no borra de
    /// cuál era.
    let active: Bool?

    /// Si procede ofrecer el enlace a la ficha del recorrido.
    ///
    /// Solo con un `true` explícito. Sin saberlo no se ofrece: llevar a alguien
    /// a una ficha que no existe es peor que no ofrecerla.
    var offersDetail: Bool { active == true }

    /// Con valores por defecto, por la misma razón que en `AttemptSummaryDTO`:
    /// el contrato va a seguir creciendo y el inicializador sintetizado obliga
    /// a tocar cada construcción a mano por cada campo nuevo.
    init(
        id: String? = nil,
        label: String? = nil,
        name: String? = nil,
        categoria: String? = nil,
        active: Bool? = nil
    ) {
        self.id = id
        self.label = label
        self.name = name
        self.categoria = categoria
        self.active = active
    }

    /// Lo que se muestra: el nombre si lo hay, y si no el código, que al menos
    /// identifica algo.
    var displayName: String? {
        name ?? label ?? id
    }

    /// El código, **solo si aporta algo que el nombre no dice**.
    ///
    /// El aspirante y el instructor hablan del recorrido por su código —«el
    /// 2B3»— y la ficha enseñaba solo «Bajada Navacerrada a Collado Villalba».
    /// Con el código delante, lo que se ve en pantalla y lo que se dice en el
    /// parque son lo mismo.
    ///
    /// `nil` cuando el nombre YA es el código, que es el caso de los recorridos
    /// sin nombre asignado: repetirlo daría «2B3 · 2B3».
    var codeIfDistinct: String? {
        guard let codigo = APISentinel.text(label) ?? APISentinel.text(id) else { return nil }
        guard let mostrado = displayName else { return nil }
        return codigo.caseInsensitiveCompare(mostrado) == .orderedSame ? nil : codigo
    }

    /// `true` si es un recorrido de prácticas.
    ///
    /// Importa porque **un intento de prácticas no mueve la nota oficial**: se
    /// puntúa y se ve, pero no ordena la oposición. Sin marcarlo, un aspirante
    /// ve un 10 en su lista que no cambia su nota y no entiende por qué.
    /// `nil` cuando el contrato no lo dice: entonces no se afirma nada.
    var isPractice: Bool? {
        switch (categoria ?? "").uppercased() {
        case "PRACTICA": true
        case "EXAMEN":   false
        default:         nil
        }
    }
}

nonisolated extension AttemptRouteDTO: Decodable {
    /// Decodifica a mano por una sola razón: `id`, `label` y `name` llegan con
    /// el centinela `"—"` cuando el intento no tiene recorrido, y aquí se
    /// convierte en `nil` de una vez.
    ///
    /// Resolverlo en el decodificador y no en cada uso es lo que permite que
    /// `displayName`, los filtros y cualquier agrupación por código traten
    /// igual las dos formas de decir «nada». Ver `APISentinel`.
    ///
    /// Cuando el backend pase el campo a `null` —acordado, en su propio PR— no
    /// hay que tocar nada aquí: las dos grafías ya son indistinguibles.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: APISentinel.text(try container.decodeIfPresent(String.self, forKey: .id)),
            label: APISentinel.text(try container.decodeIfPresent(String.self, forKey: .label)),
            name: APISentinel.text(try container.decodeIfPresent(String.self, forKey: .name)),
            categoria: try container.decodeIfPresent(String.self, forKey: .categoria),
            active: try container.decodeIfPresent(Bool.self, forKey: .active)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, name, categoria, active
    }
}

/// Una fila del desglose de la nota de un intento.
///
/// `family` es la ETIQUETA DE DISPLAY que compone el backend («Estabilidad
/// (deducciones)», «Conducción (eventos de Webfleet)»…), no una clave de
/// máquina: una fila medida y otra sin medir del mismo componente comparten
/// etiqueta. Por eso este tipo **no** es `Identifiable` — usar el índice del
/// array como identidad de render.
nonisolated struct AttemptScoreFamilyDTO: Hashable, Sendable {
    /// Identidad ESTABLE del componente (`estabilidad`, `freno_motor`,
    /// `allison`…). `family` es la etiqueta traducible y no sirve para
    /// identificar: dos filas del mismo componente la comparten.
    let key: String?

    let family: String?
    let obtained: Double?

    /// Peso efectivo del componente por 10. **No es un máximo fijo**: varía por
    /// recorrido desde que existen los pesos por recorrido.
    ///
    /// **La suma de los `max` no da 10,00 y no va a darlo.** Está documentado
    /// en el backend: con dos decimales no se puede tener a la vez el total
    /// cuadrado y la coherencia por fila. Cuadrar el total rompía
    /// `obtained <= max` —un apartado perfecto salía «1,87 / 1,88» y el informe
    /// imprimía el 99 %—, así que se eligió la coherencia por fila.
    ///
    /// Lo que sí es invariante: `obtained <= max` siempre, y un apartado
    /// perfecto cumple `obtained == max`. No derivar porcentajes de la suma de
    /// los pesos: el 100 % del criterio lo garantizan los pesos de la
    /// configuración, no esta aritmética redondeada.
    let max: Double?

    /// Por qué el componente no se midió con normalidad.
    ///
    /// `nil` = se midió bien. El resto son los estados del backend:
    /// `no_medido`, `no_evaluable`, `pendiente_enrichment`, `invalido`.
    let state: String?

    /// Motivo concreto. Solo tiene sentido con `state` presente.
    let reason: String?

    /// Explicación en castellano de por qué esta fila no tiene valor.
    ///
    /// Antes la app decía «No evaluado» sin más, porque el contrato no traía el
    /// motivo. Ahora puede decir *cuál*, que es la diferencia entre entender la
    /// nota y tener que preguntar.
    var unavailabilityDetail: String? {
        // El motivo concreto manda sobre el estado, que es más genérico.
        // Ojo con la forma: un `switch` con `default: break` es un statement,
        // no una expresión, así que aquí hace falta `return` explícito — sin
        // él los textos se evaluaban y se descartaban en silencio.
        // El vocabulario vive en `ScoreReasonCopy`, que comparten este desglose
        // y la tarjeta de la caja Allison: los dos reciben los MISMOS motivos
        // por campos distintos, y dos redacciones se habrían separado.
        if let frase = ScoreReasonCopy.sentence(for: reason) {
            return frase
        }

        // `state` es un conjunto CERRADO y documentado en el blueprint; el de
        // `motivo` es abierto —cada componente acuña el suyo— así que un switch
        // exhaustivo de motivos siempre irá por detrás. De ahí el orden: motivo
        // concreto si lo conocemos, y si no, el estado, que sí podemos cubrir
        // entero. Faltaba `no_medido`, que es justo el que llega en producción:
        // la fila de velocidad de un intento real se quedaba en «No evaluado»
        // sin decir por qué, que es lo que este método existía para evitar.
        switch state {
        case "no_medido":            return "Este apartado no se pudo medir en este intento."
        case "pendiente_enrichment": return "Pendiente de recibir los datos de flota."
        case "invalido":             return "El intento no superó las comprobaciones de validez."
        case "no_evaluable":         return "Este apartado no era evaluable en este recorrido."
        default:                     return nil
        }
    }

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
    /// La identidad que le da el backend.
    ///
    /// Es la llave con la que este evento se cruza con el del mapa
    /// (`GpsEventDTO.id`), y se añadió al contrato precisamente para eso. El
    /// cliente la ignoraba: derivaba una identidad de `type` + `timestamp`
    /// mientras la buena viajaba en la respuesta.
    ///
    /// Se ignoraba por una comprobación mal hecha de nuestro lado — se miró
    /// `Fixtures/attempt-detail.json`, que es un fixture escrito a mano en
    /// este repo, y se dio por respuesta del endpoint. Un fixture es algo que
    /// escribimos nosotros: no puede declarar sobre el contrato.
    let backendId: String?

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

    /// La confianza del DETECTOR sobre este evento: `"HIGH"` / `"LOW"`.
    ///
    /// **Texto, y comparte nombre con dos campos numéricos de otro endpoint.**
    /// `points[].confidence` y `track.confidence` del mapa son números; este es
    /// una etiqueta. No son el mismo campo con dos formas: son tres campos que
    /// comparten nombre en objetos distintos. Un DTO compartido o un
    /// decodificador genérico los junta, y ahí es donde nace el defecto —
    /// `ConfidenceIsThreeFieldsTests` lo fija.
    let confidence: String?
    let description: String?
    let timestamp: String?
    let source: String?

    /// Gravedad que le puso el DETECTOR. **No es necesariamente lo que restó**:
    /// el sensor detecta y la nota decide, y son cosas distintas.
    let penaltyPoints: Double?

    let categoria: String?

    /// Si la deducción de ESTE evento llegó a descontar.
    ///
    /// Es el campo que faltaba para poder mostrar la intensidad sin mentir. Hay
    /// eventos informativos por diseño —el badén— que llegan con gravedad alta
    /// y **no restan nada**. Sin esto, la app los presentaba como incidencias
    /// que penalizaron, atribuyéndole al aspirante algo que no ocurrió.
    let affectsScore: Bool?

    /// Por qué no penalizó, cuando `affectsScore` es falso.
    let noPenaltyReason: String?

    /// Etiqueta real del sensor (`LEVE`, `MODERADO`, `CRITICO`), en vez del
    /// número en cubos que había que reconstruir.
    let sensorSeverity: String?

    /// Explícito y con valores por defecto: el campo nuevo va primero y sin él
    /// cada test que construye un evento a mano tendría que nombrarlo.
    init(
        backendId: String? = nil,
        type: String? = nil,
        severity: Double? = nil,
        confidence: String? = nil,
        description: String? = nil,
        timestamp: String? = nil,
        source: String? = nil,
        penaltyPoints: Double? = nil,
        categoria: String? = nil,
        affectsScore: Bool? = nil,
        noPenaltyReason: String? = nil,
        sensorSeverity: String? = nil
    ) {
        self.backendId = backendId
        self.type = type
        self.severity = severity
        self.confidence = confidence
        self.description = description
        self.timestamp = timestamp
        self.source = source
        self.penaltyPoints = penaltyPoints
        self.categoria = categoria
        self.affectsScore = affectsScore
        self.noPenaltyReason = noPenaltyReason
        self.sensorSeverity = sensorSeverity
    }

    /// La identidad del backend cuando llega; si no, una derivada.
    ///
    /// La derivación sobrevive solo como respaldo: `Identifiable` dentro de un
    /// `ForEach` no admite dos filas con la misma identidad —SwiftUI reutiliza
    /// la fila equivocada—, así que tiene que haber algo. Pero la del backend
    /// gana siempre: cruzar por una llave inventada teniendo la buena en la
    /// mano es el defecto que esto cierra.
    var id: String {
        backendId ?? ((type ?? "ev") + "-" + (timestamp ?? UUID().uuidString))
    }

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
    /// El nombre se conserva por los sitios que ya lo escriben; la regla vive
    /// en `SensorIntensity`, compartida con el mapa.
    typealias SensorSeverity = SensorIntensity

    /// Intensidad, preferentemente desde la etiqueta que envía el contrato y
    /// solo si hace falta reconstruida del número.
    ///
    /// **La misma regla que usa el mapa**, y a propósito: los dos endpoints
    /// describen los mismos eventos, y una derivación por DTO es cómo la misma
    /// incidencia acaba leyéndose distinta según por dónde se abra.
    var intensity: SensorIntensity? {
        SensorIntensity.derived(label: sensorSeverity, number: severity)
    }

    /// `true` cuando este evento restó de verdad.
    ///
    /// Ante la ausencia del campo se responde `false`: afirmar que penalizó sin
    /// que el contrato lo diga es justo el error que este campo vino a cerrar.
    var didPenalise: Bool { affectsScore == true }

    /// Con qué gravedad se CALIFICÓ el evento.
    ///
    /// Es el dato con el que un aspirante entiende una deducción y, si no está
    /// de acuerdo, la nombra al pedir revisión. Estaba decodificado desde que
    /// existe el DTO y ninguna vista lo pintaba: la ficha enseñaba la
    /// intensidad del sensor, que el backend nombra por lo que es —«intensidad
    /// del canal, no la gravedad con la que se puntuó»—, así que contestaba una
    /// pregunta que nadie hacía y callaba la que sí.
    ///
    /// Los tres valores son los de `CATEGORIA_LABELS` del backend. Uno que esta
    /// versión no reconozca da `nil`: no se afirma una gravedad inventada.
    var gravity: Gravity? {
        Gravity(apiValue: categoria)
    }

    /// El color de la insignia de gravedad.
    ///
    /// **Neutro si el evento no descontó**, sea cual sea su gravedad. La ficha
    /// ya razona esto para la intensidad: hay eventos informativos por diseño
    /// —el badén— que llegan calificados y no restan nada, y pintarlos en rojo
    /// le atribuye al aspirante algo que no ocurrió. Sin `affectsScore` en el
    /// contrato tampoco se colorea: afirmar daño sin que nadie lo diga es el
    /// mismo error en su versión silenciosa.
    var gravityBadgeKind: BadgeKind {
        guard didPenalise else { return .neutral }
        return switch gravity {
        case .grave:    .danger
        case .moderada: .warning
        default:        .neutral
        }
    }

    /// Gravedad con la que el sistema calificó un evento.
    nonisolated enum Gravity: Sendable, Equatable {
        case leve, moderada, grave

        init?(apiValue: String?) {
            switch (apiValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
            case "LEVE":     self = .leve
            case "MODERADA": self = .moderada
            case "GRAVE":    self = .grave
            default:         return nil
            }
        }

        var label: String {
            switch self {
            case .leve:     "Leve"
            case .moderada: "Moderada"
            case .grave:    "Grave"
            }
        }
    }

    /// Qué decirle al aspirante cuando el evento no descontó.
    ///
    /// Descriptivo, no tranquilizador: el hecho es que no restó, y explicar por
    /// qué cuando el contrato lo dice.
    var noPenaltyLabel: String {
        switch noPenaltyReason {
        case "informativo", "evento_informativo":
            "Registrado a título informativo: no ha restado puntuación."
        case "dentro_de_tolerancia", "franquicia":
            // «permitida», no «admitida»: el margen lo permite la configuración
            // de puntuación, y «admitido» es la palabra con la que la
            // resolución nombra a quien entra. No pinta nada en una frase sobre
            // el umbral de un sensor.
            "Dentro de la tolerancia permitida: no ha restado puntuación."
        default:
            "No ha restado puntuación."
        }
    }
}

nonisolated extension AttemptEventDTO: Decodable {
    /// Lectura tolerante, como en el mapa.
    ///
    /// **El cuarto array del contrato al que le faltaba la regla.** «Un tipo
    /// inesperado no puede hundir la respuesta» estaba escrita y probada en
    /// `GpsEventDTO`, se aplicó a `GpsPointDTO` cuando `confidence` resultó ser
    /// un número, y aquí seguían once `decodeIfPresent` estrictos: una sorpresa
    /// en cualquiera de ellos tiraba la ficha ENTERA, que es la pantalla donde
    /// un aspirante entiende una deducción y la nombra si quiere revisarla.
    ///
    /// No es una hipótesis: `severity` ya llegó como texto por este mismo
    /// endpoint una vez, y `points[].confidence` era un número declarado como
    /// cadena. Tres veces el mismo agujero en dos días, y las tres con la regla
    /// ya escrita en el archivo de al lado.
    ///
    /// `backendId` mantiene su `APISentinel` porque la identidad SÍ es
    /// estructural: sin ella no hay cruce con el mapa.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            // Por `APISentinel`: una cadena vacía no es una identidad, y
            // dejarla pasar haría colisionar en "" a todos los eventos sin id.
            backendId: APISentinel.text(c.lenientString(forKey: .id)),
            type: c.lenientString(forKey: .type),
            severity: c.lenientDouble(forKey: .severity),
            confidence: c.lenientLabel(forKey: .confidence),
            description: c.lenientString(forKey: .description),
            timestamp: c.lenientString(forKey: .timestamp),
            source: c.lenientString(forKey: .source),
            penaltyPoints: c.lenientDouble(forKey: .penaltyPoints),
            categoria: c.lenientLabel(forKey: .categoria),
            affectsScore: c.lenientBool(forKey: .affectsScore),
            noPenaltyReason: c.lenientString(forKey: .noPenaltyReason),
            sensorSeverity: c.lenientLabel(forKey: .sensorSeverity)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, severity, confidence, description, timestamp, source
        case penaltyPoints, categoria, affectsScore, noPenaltyReason, sensorSeverity
    }
}

struct AttemptDetailDTO: Sendable {
    let id: String?
    let candidate: AttemptCandidateDTO?
    let route: AttemptRouteDTO?
    /// Nota publicada. **Un decimal significativo**, confirmado por el equipo
    /// de Training: es 8,5, no 8,50.
    let score: Double?

    /// La misma nota con dos decimales.
    ///
    /// Existía en la base y no salía del backend; ahora viaja. Es la que se
    /// acerca a la suma de las filas del desglose (±0,01 por fila), porque
    /// `score` ya perdió un decimal. La exacta —8,464375 en el intento con el
    /// que se verificó esto— no se publica.
    ///
    /// La suma de las filas NUNCA reproducirá `score`. Enseñar el desglose sin
    /// decirlo deja a un aspirante sumando 8,45 contra un 8,5 y concluyendo que
    /// hay un error.
    let scoreRaw: Double?

    let dataQuality: String?

    /// Calidad clasificada. `nil` cuando el backend no la envió o el valor es
    /// desconocido — en ese caso no se pinta insignia.
    var quality: DataQuality? { DataQuality(apiValue: dataQuality) }
    let scoreBreakdown: [AttemptScoreFamilyDTO]
    let events: [AttemptEventDTO]
    let convocatoriaId: String?

    // MARK: - Los cuatro bloques de conducción (bloque C)
    //
    // Contestan «qué nota tengo y en qué he fallado» cuando falta la mitad de
    // estabilidad. Los cuatro son `null` en muchos intentos reales y `null` no
    // es un error: es «este intento no lo tiene».
    //
    // ⚠ `partialWebfleet` y `drivingNarrative` llegan `null` cuando el
    // indicador de Webfleet no es la ventana del PROPIO intento. Los intentos
    // enriquecidos antes del 2026-08-06 guardan el preset SEMANAL, y
    // atribuirle al aspirante la conducción del camión durante la semana es
    // imputarle conducta ajena. Ese `null` es el backend negándose a hacerlo,
    // así que el cliente no lo rellena ni lo trata como fallo.

    let allison: AllisonDTO?
    let partialWebfleet: PartialWebfleetDTO?
    let drivingNarrative: DrivingNarrativeDTO?

    /// ¿Se preguntó a Webfleet y no había viaje en la ventana?
    ///
    /// Distinto de «todavía no se ha preguntado», y la diferencia importa:
    /// decir «pendiente» a esto manda al aspirante a esperar algo que no va a
    /// llegar. `nil` en un servidor que no lo manda — que tampoco es lo mismo.
    let webfleetQueriedNoTrip: Bool?

    /// Si hay algo de conducción que enseñar.
    var showsDrivingBlocks: Bool {
        allison != nil || partialWebfleet != nil || drivingNarrative != nil
    }

    /// Los datos de conducción no van a llegar, y hay que decirlo así.
    ///
    /// Solo con un `true` explícito: la ausencia del campo no afirma nada, y
    /// afirmar que algo no llegará cuando no se sabe es peor que callar.
    var drivingDataWillNotArrive: Bool { webfleetQueriedNoTrip == true }
}

nonisolated extension AttemptDetailDTO: Decodable {}
