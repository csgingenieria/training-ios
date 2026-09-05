import Foundation

enum AppEnvironment {
    /// Base URL del backend Training. Lee de Info.plist injectado por .xcconfig.
    /// - Debug:     http://localhost:5000
    /// - Staging:   https://staging.cmadrid-training.com
    /// - Release:   https://training.dobacksoft.com
    nonisolated static var baseURL: URL {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String,
              let url = URL(string: urlString) else {
            fatalError("BASE_URL no configurado en Info.plist. Revisar .xcconfig para el esquema activo.")
        }
        return url
    }

    /// Versión del cliente para User-Agent.
    nonisolated static let clientVersion = "ios-v1-alpha"

    /// User-Agent estándar para todas las requests.
    nonisolated static var userAgent: String {
        let device = "iOS"
        return "DobacksoftTraining/\(clientVersion) (\(device))"
    }
}
