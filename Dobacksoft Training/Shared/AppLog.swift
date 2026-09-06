import Foundation
import os

/// Loggers de la app, por subsistema.
///
/// Antes no había ninguno: un fallo de Keychain o un error de transporte se
/// convertían en un mensaje genérico en pantalla y desaparecían. Con `Logger`
/// quedan en el registro unificado y se leen con Consola o `log stream`, sin
/// añadir dependencias ni enviar nada a terceros.
///
/// **Nunca registrar tokens, credenciales ni datos personales de aspirantes.**
/// Los datos de CMadrid están bajo NDA y el registro unificado es legible por
/// cualquiera con acceso al dispositivo.
///
/// Los tres son `nonisolated`: los usa `APIClient`, que es un `actor`, y en
/// aislamiento estricto un global aislado al hilo principal no se puede leer
/// desde ahí. `Logger` es `Sendable`, así que no hace falta más.
enum AppLog {
    nonisolated private static let subsystem = Bundle.main.bundleIdentifier ?? "com.dobacksoft.training"

    nonisolated static let auth = Logger(subsystem: subsystem, category: "auth")
    nonisolated static let api = Logger(subsystem: subsystem, category: "api")
    nonisolated static let keychain = Logger(subsystem: subsystem, category: "keychain")
}
