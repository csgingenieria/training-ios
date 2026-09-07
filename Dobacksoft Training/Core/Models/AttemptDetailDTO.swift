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

    /// Lo que se muestra: el nombre si lo hay, y si no el código, que al menos
    /// identifica algo.
    var displayName: String? {
        name ?? label ?? id
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
            categoria: try container.decodeIfPresent(String.self, forKey: .categoria)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, name, categoria
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
        switch reason {
        case "sin_datos_can":
            return "El vehículo no entregó datos de la caja."
        case "sin_minimo_configurado":
            return "Este recorrido no tiene mínimo fijado para este apartado."
        case "config_invalida":
            return "La configuración de este apartado no era válida."
        case "no_registrado":
            return "No se registró actividad en este apartado."
        case "webfleet_poco_muestreo":
            return "Los datos de flota no tuvieron muestreo suficiente para evaluarlo."
        default:
            break
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

    let confidence: String? // "HIGH" / "LOW"
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

    var id: String { (type ?? "ev") + "-" + (timestamp ?? UUID().uuidString) }

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
    /// Se reconstruyen desde los cubos del backend (LEVE 0,3 · MODERADO 0,6 ·
    /// CRÍTICO 0,95). Nunca presentar `severity` como escala continua: ver la
    /// nota del campo.
    enum SensorSeverity: String, Sendable {
        case leve = "Leve"
        case moderada = "Moderada"
        case critica = "Crítica"
    }

    /// Intensidad, preferentemente desde la etiqueta que ahora envía el
    /// contrato, y solo si hace falta reconstruida del número.
    ///
    /// La etiqueta es mejor fuente: el número venía en cubos y con un centinela
    /// 0,5 para «no se supo clasificar», que reconstruido caía en «moderada» —
    /// una intensidad que nadie midió.
    var intensity: SensorSeverity? {
        switch (sensorSeverity ?? "").uppercased() {
        case "LEVE":     return .leve
        case "MODERADO": return .moderada
        case "CRITICO":  return .critica
        default: break
        }
        guard let severity, severity != 0.5 else { return nil }
        switch severity {
        case ..<0.45: return .leve
        case ..<0.8:  return .moderada
        default:      return .critica
        }
    }

    /// `true` cuando este evento restó de verdad.
    ///
    /// Ante la ausencia del campo se responde `false`: afirmar que penalizó sin
    /// que el contrato lo diga es justo el error que este campo vino a cerrar.
    var didPenalise: Bool { affectsScore == true }

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

nonisolated extension AttemptEventDTO: Decodable {}

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
}

nonisolated extension AttemptDetailDTO: Decodable {}
