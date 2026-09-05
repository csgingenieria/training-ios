import Foundation

enum AppEnvironment {
    /// Base URL del backend Training. Lee de Info.plist inyectado por .xcconfig.
    ///
    /// Los valores reales viven en `Config/*.xcconfig` y son la única fuente de
    /// verdad; no duplicarlos aquí. Al cierre de esta nota, Debug apuntaba al
    /// VPS de staging, no a `localhost`: comprobá el `.xcconfig` de tu esquema
    /// antes de asumir contra qué entorno estás corriendo.
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
