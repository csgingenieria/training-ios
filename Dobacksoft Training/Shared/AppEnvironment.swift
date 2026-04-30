import Foundation

enum AppEnvironment {
    /// Base URL del backend Training. Cambiá para apuntar a VPS / staging.
    /// - LOCAL Simulator: `http://localhost:5000` (Flask dev en la Mac).
    /// - LOCAL device físico: reemplazá por la IP de la Mac en LAN, ej. `http://192.168.1.10:5000`.
    /// - VPS prod: `https://<dominio-cmadrid>.com:4000`.
    static var baseURL: URL {
        #if DEBUG
        return URL(string: "http://localhost:5000")!
        #else
        // TODO: poner el dominio público real cuando esté listo
        return URL(string: "https://training.example.com")!
        #endif
    }

    /// Versión del cliente para User-Agent.
    static let clientVersion = "ios-v1-alpha"

    /// User-Agent estándar para todas las requests.
    static var userAgent: String {
        let device = "iOS"
        return "DobacksoftTraining/\(clientVersion) (\(device))"
    }
}
