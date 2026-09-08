import Foundation

/// Lo que se guarda del puesto de un aspirante para un arranque sin cobertura.
///
/// **Una proyección, no el DTO.** Los DTO de este proyecto son `Decodable` a
/// propósito —el cliente lee el contrato, no lo emite— y hacerlos `Encodable`
/// para poder guardarlos erosionaría esa restricción en toda la app por una
/// necesidad de una pantalla.
///
/// Y porque guardar el DTO entero guardaría más de lo necesario. El widget ya
/// lo tiene escrito: «lo que este tipo NO lleva, y no por olvido… Un campo que
/// no existe no se puede pintar por error». Aquí igual.
///
/// **Lo que NO lleva:** correo, nombre de persona, identificador de usuario,
/// identificador de convocatoria, plaza, cupo ni nada parecido a una línea de
/// corte. Lo que lleva es lo que la tarjeta enseña.
///
/// No es la instantánea del widget y no se reutiliza esa. Aquella vive en el App
/// Group y **está apagada por defecto citando el RGPD art. 25.2**, porque la ve
/// cualquiera que mire la pantalla de inicio. Usar un consentimiento dado para
/// eso como caché de otra cosa sería usar un dato para un fin distinto del que
/// se autorizó. Esto vive en el contenedor privado de la app, es del propio
/// aspirante, se borra al cerrar sesión y no sale del dispositivo.
nonisolated struct StandingCache: Codable, Sendable, Equatable {
    /// Un lector que encuentre una versión mayor que la suya la trata como
    /// ilegible, no intenta adivinar. Mismo criterio que la instantánea.
    static let currentSchemaVersion = 1

    let schemaVersion: Int

    /// Nombre de la convocatoria. Es un dato público del proceso, no de nadie.
    let convocatoriaName: String?

    let position: Int?
    let totalParticipants: Int?

    /// La nota tal como se publica.
    let score: Double?

    /// Ya resuelta por la app, no derivada aquí: `GradeFinality` sale del
    /// estado de la CONVOCATORIA, que esta caché no guarda.
    let finality: GradeFinality.Persisted?

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        convocatoriaName: String?,
        position: Int?,
        totalParticipants: Int?,
        score: Double?,
        finality: GradeFinality.Persisted?
    ) {
        self.schemaVersion = schemaVersion
        self.convocatoriaName = convocatoriaName
        self.position = position
        self.totalParticipants = totalParticipants
        self.score = score
        self.finality = finality
    }

    /// Si la puede leer esta versión.
    var isReadable: Bool { schemaVersion <= Self.currentSchemaVersion }
}

nonisolated extension GradeFinality {
    /// La finalidad en una forma que se puede guardar.
    ///
    /// `GradeFinality` no es `Codable` y no se le añade: su valor se DERIVA del
    /// estado de la convocatoria y hacerlo persistible invitaría a guardarlo en
    /// sitios donde luego se leería sin ese estado delante.
    enum Persisted: String, Codable, Sendable {
        case provisional
        case pendingConfirmation
        case definitive
        case unknown
    }

    var persisted: Persisted {
        switch self {
        case .provisional:         .provisional
        case .pendingConfirmation: .pendingConfirmation
        case .definitive:          .definitive
        case .unknown:             .unknown
        }
    }

    init(persisted: Persisted) {
        switch persisted {
        case .provisional:         self = .provisional
        case .pendingConfirmation: self = .pendingConfirmation
        case .definitive:          self = .definitive
        case .unknown:             self = .unknown
        }
    }
}
