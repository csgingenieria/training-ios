import Foundation

/// Lo que la app deposita para que lo lean las superficies secundarias
/// (widget hoy, reloj más adelante).
///
/// La app iOS es el **único proceso que habla con el backend**. Widget y reloj
/// no tienen credenciales ni hacen red: solo pintan esta instantánea fechada.
/// Esa decisión no es de comodidad — evita repartir el token de un aspirante
/// por procesos que no lo necesitan, y quita de encima el refresco concurrente
/// desde una extensión.
///
/// **Lo que este tipo NO lleva, y no por olvido**: identificador de usuario,
/// correo, nombre de persona, identificador de convocatoria, plaza, cupo ni
/// línea de corte. Un campo que no existe no se puede pintar por error. No
/// añadirlos «solo para la vista pequeña».
nonisolated struct StandingSnapshot: Codable, Sendable, Equatable {
    /// Versión del formato. Un lector que encuentre una mayor que la suya debe
    /// tratarla como ilegible, no intentar adivinar.
    static let currentSchemaVersion = 1

    let schemaVersion: Int

    /// Monotónico. Permite descartar una carga más vieja que la ya presente.
    let generation: Int

    /// Cuándo se consultó el dato. **Obligatorio**: sin él no se puede saber si
    /// lo que se muestra sigue siendo cierto, y un puesto de hace tres días
    /// presentado como actual es tan falso como uno inventado.
    let capturedAt: Date

    let content: Content

    init(generation: Int, capturedAt: Date, content: Content) {
        self.schemaVersion = Self.currentSchemaVersion
        self.generation = generation
        self.capturedAt = capturedAt
        self.content = content
    }

    /// Qué hay que contar. Cada caso es un estado distinto con su propio texto:
    /// ninguno se solapa con «no lo sé», que se representa fuera de este tipo.
    enum Content: Codable, Sendable, Equatable {
        /// El aspirante no ha activado la vista rápida. Estado de fábrica.
        case desactivado
        /// La sesión no es de un aspirante (MANAGER, ADMIN, SUPER_ADMIN).
        case sinPosicionPropia
        /// Hay sesión de aspirante, pero todavía no se ha consultado la posición.
        case sinDatosAun
        /// No consta ninguna inscripción.
        case sinConvocatoria
        /// Inscrito y todavía sin posición: no ha conducido nada.
        case sinPosicion(convocatoriaName: String)
        /// Hay posición.
        case posicion(Standing)
    }

    struct Standing: Codable, Sendable, Equatable {
        let convocatoriaName: String
        let position: Int
        let totalCandidates: Int

        /// Opcional a propósito, aunque `StandingDTO.score` no lo sea: si el
        /// backend manda algo de lo que no nos fiamos, no se transporta.
        let score: Double?

        /// Total de intentos registrados. **No** se transporta
        /// `attemptsCompleted`: cuenta recorridos, no intentos, y la fracción
        /// entre ambos no describe ningún progreso real.
        let attemptsTotal: Int

        let finality: Finality
    }

    /// Copia local de `GradeFinality`, resuelta por la app.
    ///
    /// La app la calcula del estado de la CONVOCATORIA, que el widget no
    /// tiene. Viaja ya resuelta para que ninguna superficie la derive por su
    /// cuenta de `StandingDTO.status`, que es el estado de la matrícula.
    enum Finality: String, Codable, Sendable {
        case provisional
        case definitiva
        case desconocida
    }

    // MARK: - Serialización

    /// Codificador único. Expuesto aquí para que ningún consumidor use uno
    /// distinto: una estrategia de fechas diferente entre escritor y lector
    /// rompería la lectura en silencio.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
