import SwiftUI

/// Tapa las credenciales cuando la app corre bajo un test de UI.
///
/// «Mi PIN de tablet» es la única pantalla cuyo contenido **es** una credencial:
/// con el PIN y el número de inscripción se puede conducir en nombre de otra
/// persona. El test que la ejercita no la captura y no lee sus dígitos, pero eso
/// no basta: XCTest saca capturas del sistema por su cuenta y, con el ajuste por
/// defecto, las **conserva cuando el test falla**. Así que el día que ese test
/// falle, el PIN de alguien acabaría en un bundle de resultados que se comparte.
///
/// La única garantía verdadera es que en una corrida de test la cifra **no
/// llegue a dibujarse**. Con `-uitest-redact-secrets` se aplica
/// `.redacted(reason: .privacy)`, que es lo que `.privacySensitive()` marca:
/// la pantalla sigue resolviendo, sus estados y su advertencia se pueden
/// comprobar, y no hay nada sensible que capturar ni en verde ni en rojo.
///
/// Fuera de un test no hace nada: se decide por un argumento de lanzamiento que
/// solo pasa el runner, y la app instalada nunca lo lleva.
nonisolated enum SecretRedaction {
    static let launchArgument = "-uitest-redact-secrets"

    static var isActive: Bool {
        CommandLine.arguments.contains(launchArgument)
    }
}

extension View {
    /// Para lo que es una credencial, no solo un dato personal.
    ///
    /// Va junto a `.privacySensitive()`, que es quien marca QUÉ se tapa; esto
    /// decide CUÁNDO. Sin los dos, `.privacySensitive()` es un marcador que hoy
    /// no tapa nada.
    func redactedInUITests() -> some View {
        redacted(reason: SecretRedaction.isActive ? .privacy : [])
    }
}
