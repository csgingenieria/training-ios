import Foundation

enum AppEnvironment {
    /// Configuración ausente o inservible en el Info.plist del build.
    ///
    /// Diagnóstico de desarrollo, en inglés: nunca lo lee el usuario final
    /// (`APIError.configuration` ignora este payload y muestra su propio
    /// mensaje formal), pero sí acaba en logs y en el informe de soporte.
    enum ConfigurationError: Error, CustomStringConvertible {
        case missingBaseURL
        case malformedBaseURL(String)

        var description: String {
            switch self {
            case .missingBaseURL:
                "BASE_URL is missing from Info.plist. Check the active scheme's .xcconfig."
            case let .malformedBaseURL(value):
                "BASE_URL is not a valid absolute URL: «\(value)». It must include scheme and host."
            }
        }
    }

    /// Base URL del backend Training. Lee de Info.plist inyectado por .xcconfig.
    ///
    /// Los valores reales viven en `Config/*.xcconfig` y son la única fuente de
    /// verdad; no duplicarlos aquí. Al cierre de esta nota, Debug apuntaba al
    /// VPS de staging, no a `localhost`: comprobá el `.xcconfig` de tu esquema
    /// antes de asumir contra qué entorno estás corriendo.
    ///
    /// Antes esto llamaba a `fatalError`, así que un build mal configurado se
    /// cerraba de golpe al arrancar en manos del usuario final. Ahora falla de
    /// forma explícita y la app puede contarlo.
    nonisolated static func baseURL() throws -> URL {
        try resolveBaseURL(from: Bundle.main.infoDictionary ?? [:])
    }

    /// Núcleo de la resolución, aislado del `Bundle` para poder probarlo.
    nonisolated static func resolveBaseURL(from info: [String: Any]) throws -> URL {
        guard let raw = info["BASE_URL"] as? String else {
            throw ConfigurationError.missingBaseURL
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ConfigurationError.missingBaseURL
        }

        // Una cadena relativa como "example.org" produce una URL válida pero
        // inservible como base: las peticiones no irían a ninguna parte.
        guard let url = URL(string: trimmed), url.scheme != nil, url.host() != nil else {
            throw ConfigurationError.malformedBaseURL(trimmed)
        }

        return url
    }

    /// Host de la base URL para mostrarlo en pantallas de diagnóstico.
    /// Devuelve `nil` si la configuración es inválida, en lugar de propagar:
    /// una etiqueta informativa no debe romper la vista que la contiene.
    nonisolated static var baseURLHost: String? {
        try? baseURL().host()
    }

    /// Versión del cliente para User-Agent.
    nonisolated static let clientVersion = "ios-v1-alpha"

    /// User-Agent estándar para todas las requests.
    nonisolated static var userAgent: String {
        let device = "iOS"
        return "DobacksoftTraining/\(clientVersion) (\(device))"
    }
}
