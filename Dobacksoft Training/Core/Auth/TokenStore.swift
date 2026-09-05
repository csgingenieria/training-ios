import Foundation
import Security

/// Almacenamiento de tokens en Keychain. NO usar UserDefaults — los tokens son sensibles.
///
/// Cada operación informa de su resultado. Antes se descartaba el `OSStatus`, así
/// que un Keychain inaccesible —dispositivo bloqueado, entitlements mal puestos—
/// era indistinguible de «no hay sesión guardada»: la app mandaba al login sin
/// que nadie supiera que el almacén estaba roto.
///
/// La ausencia sí es una respuesta válida: `load` devuelve `nil` ante
/// `errSecItemNotFound`, y `delete` acepta borrar algo que no está.
enum TokenStore {
    private static let service = "Com.Dobacksoft-Training.tokens"

    enum Key: String, CaseIterable {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }

    struct Failure: Error, CustomStringConvertible {
        let status: OSStatus
        let operation: String

        static func keychain(status: OSStatus, operation: String) -> Failure {
            Failure(status: status, operation: operation)
        }

        var description: String {
            let detail = SecCopyErrorMessageString(status, nil) as String? ?? "sin descripción"
            return "Keychain falló en \(operation) (OSStatus \(status)): \(detail)"
        }
    }

    private static func baseQuery(for key: Key) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue,
        ]
    }

    static func save(_ value: String, for key: Key) throws {
        try delete(for: key)

        var attrs = baseQuery(for: key)
        attrs[kSecValueData] = Data(value.utf8)
        attrs[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw Failure.keychain(status: status, operation: "save(\(key.rawValue))")
        }
    }

    /// Devuelve `nil` cuando no hay nada guardado; lanza si el Keychain falló.
    static func load(for key: Key) throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
                throw Failure.keychain(status: status, operation: "load(\(key.rawValue)): dato ilegible")
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw Failure.keychain(status: status, operation: "load(\(key.rawValue))")
        }
    }

    static func delete(for key: Key) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure.keychain(status: status, operation: "delete(\(key.rawValue))")
        }
    }

    /// Borra ambas claves. Intenta las dos aunque la primera falle, y propaga el
    /// primer fallo: al cerrar sesión importa más vaciar todo que abortar pronto.
    static func clearAll() throws {
        var firstFailure: Error?
        for key in Key.allCases {
            do {
                try delete(for: key)
            } catch {
                firstFailure = firstFailure ?? error
            }
        }
        if let firstFailure { throw firstFailure }
    }
}
