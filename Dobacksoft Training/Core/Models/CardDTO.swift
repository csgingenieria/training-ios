import Foundation

/// `GET /api/v1/me/card` — con qué tarjeta va a conducir el aspirante.
///
/// Es **solo texto**: el cliente no lee el chip y no abre Core NFC. El caso de
/// uso está escrito en el propio backend, y es de campo: delante del camión,
/// comprobar que el plástico que lleva encima es el que el sistema espera. Y si
/// no tiene, enterarse **antes** de llegar allí — sin tarjeta no se puede abrir
/// un intento, y descubrirlo en el parque es tarde.
///
/// `cardUid` viaja completo, con paridad exacta con el portal, que lo pinta
/// entero. El UID va impreso en el plástico y enseñarlo es lo que permite la
/// comparación visual que justifica la pantalla.
nonisolated struct CardDTO: Sendable, Hashable {
    /// Si el sistema le tiene asignada una tarjeta.
    let hasCard: Bool?

    /// El UID impreso en el plástico.
    let cardUid: String?

    /// El número de conductor en la flota. **No es el de la tarjeta**: son dos
    /// identificadores distintos de la misma persona, y comparar el que no toca
    /// contra el plástico no prueba nada.
    let webfleetDriverNo: String?

    /// Si puede abrir un intento hoy.
    ///
    /// Exige tarjeta **y** número. Un `hasCard: true` sin UID es una
    /// contradicción y no se resuelve en la dirección optimista: la pantalla no
    /// puede ofrecer una comparación para la que no tiene número, así que deja
    /// de afirmar que está listo.
    var canDriveToday: Bool {
        hasCard == true && cardUid != nil
    }

    /// Si tiene que hablar con su instructor antes de la prueba.
    ///
    /// Solo cuando el contrato lo dice. Con un servidor que no manda los campos
    /// no se sabe, y mandar a alguien a resolver un problema que quizá no tiene
    /// es tan malo como callarse el que sí tiene.
    var needsInstructor: Bool {
        hasCard != nil && !canDriveToday
    }
}

nonisolated extension CardDTO: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            hasCard: try c.decodeIfPresent(Bool.self, forKey: .hasCard),
            // El centinela otra vez: el portal formatea para Jinja, así que un
            // UID ausente puede llegar como «—» o en blanco. Ninguno de los dos
            // es una tarjeta, y con cualquiera de ellos no hay nada que
            // comparar delante del camión.
            cardUid: APISentinel.text(try c.decodeIfPresent(String.self, forKey: .cardUid)),
            webfleetDriverNo: APISentinel.text(try c.decodeIfPresent(String.self, forKey: .webfleetDriverNo))
        )
    }

    private enum CodingKeys: String, CodingKey {
        case hasCard, cardUid, webfleetDriverNo
    }
}
