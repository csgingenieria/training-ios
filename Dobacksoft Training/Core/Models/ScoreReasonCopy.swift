import Foundation

/// Por qué un apartado no se pudo medir, en castellano.
///
/// Vivía dentro de `AttemptScoreFamilyDTO.unavailabilityDetail`, acoplado al
/// `state` del desglose. La caja Allison trae los MISMOS motivos por otro
/// campo, así que se extrae: dos redacciones de «sin_datos_can» se separan a
/// la primera corrección, y ya pasó una vez con el aviso legal, que estaba
/// escrito a mano en dos vistas.
///
/// El vocabulario de motivos es **abierto** por diseño —cada componente acuña
/// el suyo— así que un `switch` exhaustivo siempre irá por detrás. De ahí el
/// contrato: `nil` cuando no se reconoce, y que decida el llamador, que sabe
/// qué decir en su sitio.
nonisolated enum ScoreReasonCopy {
    static func sentence(for reason: String?) -> String? {
        switch reason?.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "sin_datos_can":
            "El vehículo no entregó datos de la caja."
        case "sin_minimo_configurado":
            "Este recorrido no tiene mínimo fijado para este apartado."
        case "config_invalida":
            "La configuración de este apartado no era válida."
        case "no_registrado":
            "No se registró actividad en este apartado."
        case "webfleet_poco_muestreo":
            "Los datos de flota no tuvieron muestreo suficiente para evaluarlo."
        default:
            nil
        }
    }
}

/// Lo que dice la tarjeta de la caja de cambios.
nonisolated enum AllisonCopy {
    /// El cumplimiento, con los DOS porcentajes en la mano.
    ///
    /// Aquí es donde el ⚠ del backend se convierte en una frase. `compliancePct`
    /// topa en 100 y `rawCompliancePct` no, así que:
    ///
    /// - Escribir el bruto como «cumplimiento» le acredita al aspirante algo
    ///   que el criterio no premia: pasarse del mínimo no suma.
    /// - Escribir solo el topado esconde que se pasó, que es un hecho suyo y
    ///   merece decirse.
    ///
    /// Por eso la frase distingue los dos casos en vez de imprimir un número.
    static func compliance(_ allison: AllisonDTO) -> String {
        guard let topado = allison.compliancePct else {
            return "No consta el cumplimiento de este apartado."
        }

        if allison.exceededTheMinimum {
            // Sin cifra del bruto a propósito: el número que cuenta para la
            // nota es el topado, y enseñar «140 %» al lado de «cumplimiento»
            // acreditaría un crédito que no existe.
            return "Usó la caja por encima del mínimo exigido, que ya cuenta como cumplimiento completo."
        }

        if topado >= 100 {
            return "Cumplió el mínimo exigido en este apartado."
        }

        return "Cumplió el \(ScoreFormat.attempt(topado)) % del mínimo exigido en este apartado."
    }

    /// Cuando no se pudo evaluar.
    ///
    /// Descriptivo y del lado del sistema: el motivo es del vehículo o de la
    /// configuración, y ninguno es una omisión del aspirante.
    static func unevaluated(reason: String?) -> String {
        ScoreReasonCopy.sentence(for: reason)
            ?? "No se pudo evaluar este apartado en este intento."
    }
}
