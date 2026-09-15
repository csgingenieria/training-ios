import Foundation

/// Los cuatro bloques de conducción de la ficha del intento.
///
/// Contestan «qué nota tengo y en qué he fallado» cuando falta la mitad de
/// estabilidad, que es la pregunta que la ficha no sabía responder. Los cuatro
/// son `null` en muchos intentos reales, y `null` **no es un error**: es «este
/// intento no lo tiene». Pintar una tarjeta vacía se leería como un cero, y un
/// cero es una afirmación sobre el conductor.

// MARK: - La caja Allison

/// La caja del bus CAN de la vuelta que condujo el aspirante.
///
/// Es su dato: sale del bus del camión durante su vuelta, y tiene el mismo
/// derecho a estar en la ficha que el freno motor.
nonisolated struct AllisonDTO: Sendable, Hashable {
    /// Si se pudo evaluar. Con `false`, `reason` dice por qué.
    let evaluated: Bool?
    let reason: String?

    let presses: Int?
    let minimumPresses: Int?

    /// Cumplimiento **topado en 100**: pasarse del mínimo no suma.
    let compliancePct: Double?

    /// Cumplimiento **sin topar**. No es `compliancePct` sin redondear: son dos
    /// números distintos, y confundirlos le atribuiría al aspirante un
    /// cumplimiento que el criterio no le reconoce, o le ocultaría que se pasó
    /// del mínimo.
    let rawCompliancePct: Double?

    let outOfTen: Double?
    let deduction: Double?
    let weight: Double?
    let max: Double?
    let contribution: Double?
    let maxPenalty: Double?
    let curveExponent: Double?

    /// Si se pasó del mínimo exigido.
    ///
    /// Es la única lectura que necesita los DOS porcentajes, y por eso vive
    /// aquí: cualquier pantalla que lo derive de uno solo se equivoca.
    var exceededTheMinimum: Bool {
        guard let compliancePct, let rawCompliancePct else { return false }
        return rawCompliancePct > compliancePct
    }
}

nonisolated extension AllisonDTO: Decodable {}

// MARK: - La mitad de Webfleet

/// La conducción cuando falta la estabilidad: solo el agregado.
///
/// **Nunca la lista de viajes.** Un viaje concreto del camión no es una
/// afirmación sobre la vuelta del aspirante.
nonisolated struct PartialWebfleetDTO: Sendable, Hashable {
    let optidrive: Double?

    /// Sobre diez, que es la escala en la que se lee una nota. **No es la
    /// nota**: falta la mitad de estabilidad, y `missing` lo dice.
    let outOfTen: Double?

    let distanceKm: Double?
    let durationMin: Int?
    let tripCount: Int?

    /// Qué falta para que esto sea una nota. Su presencia es lo que prueba que
    /// `outOfTen` es media respuesta.
    let missing: String?

    /// Con qué peso entra este apartado en la nota, según el criterio vigente.
    /// La tarjeta lo dice con este número o no dice ninguno.
    let drivingWeightPct: Double?

    /// Si lo que hay es media nota y no la nota.
    var isHalfOfTheGrade: Bool { missing?.isEmpty == false }
}

nonisolated extension PartialWebfleetDTO: Decodable {}

// MARK: - La narrativa de conducción

/// La lectura agregada de su conducción, en hasta cinco puntos.
nonisolated struct DrivingNarrativeDTO: Sendable, Hashable {
    let outOfTen: Double?
    let optidrive: Double?
    let points: [DrivingPointDTO]

    /// `true` siempre que llega: es la MITAD, porque la estabilidad la aporta
    /// el Doback y no está.
    let isPartial: Bool?
    let missing: String?
    let distanceKm: Double?
    let durationMin: Int?
}

nonisolated extension DrivingNarrativeDTO: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            outOfTen: try c.decodeIfPresent(Double.self, forKey: .outOfTen),
            optidrive: try c.decodeIfPresent(Double.self, forKey: .optidrive),
            points: try c.decodeIfPresent([DrivingPointDTO].self, forKey: .points) ?? [],
            isPartial: try c.decodeIfPresent(Bool.self, forKey: .isPartial),
            missing: try c.decodeIfPresent(String.self, forKey: .missing),
            distanceKm: try c.decodeIfPresent(Double.self, forKey: .distanceKm),
            durationMin: try c.decodeIfPresent(Int.self, forKey: .durationMin)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case outOfTen, optidrive, points, isPartial, missing, distanceKm, durationMin
    }
}

/// Un punto de la narrativa: un aspecto de su conducción, con su frase.
nonisolated struct DrivingPointDTO: Sendable, Hashable, Identifiable {
    let title: String?
    /// La frase la escribe el backend y la pinta el cliente tal cual: es la
    /// explicación, y reescribirla aquí la separaría de la del portal.
    let detail: String?
    let level: DrivingLevel?
    let outOfTen: Double?

    var id: String { title ?? detail ?? "" }
}

nonisolated extension DrivingPointDTO: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            title: try c.decodeIfPresent(String.self, forKey: .title),
            detail: try c.decodeIfPresent(String.self, forKey: .detail),
            level: DrivingLevel(apiValue: try c.decodeIfPresent(String.self, forKey: .level)),
            outOfTen: try c.decodeIfPresent(Double.self, forKey: .outOfTen)
        )
    }

    private enum CodingKeys: String, CodingKey { case title, detail, level, outOfTen }
}

/// Cómo salió un aspecto de la conducción.
nonisolated enum DrivingLevel: Sendable, Hashable {
    case bueno, regular, malo, neutro

    init?(apiValue: String?) {
        switch (apiValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "bueno":   self = .bueno
        case "regular": self = .regular
        case "malo":    self = .malo
        case "neutro":  self = .neutro
        default:        return nil
        }
    }

    var label: String {
        switch self {
        case .bueno:   "Bien"
        case .regular: "Regular"
        case .malo:    "A mejorar"
        case .neutro:  "Dato"
        }
    }

    /// El color del punto. `neutro` no lleva color a propósito: es información
    /// sin juicio, y pintarla lo convertiría en uno.
    var badgeKind: BadgeKind {
        switch self {
        case .bueno:   .success
        case .regular: .warning
        case .malo:    .danger
        case .neutro:  .neutral
        }
    }
}
