import Foundation

/// Marker class used only to resolve the test bundle at runtime.
///
/// `Bundle.module` is synthesised by SwiftPM and does not exist in an Xcode
/// test target, so the bundle is resolved from a type that lives inside it.
private final class BundleToken {}

/// Helper para cargar fixtures JSON desde el bundle de tests.
/// Los archivos .json viven en `Dobacksoft TrainingTests/Fixtures/`.
enum JSONFixture {
    /// Errors raised while resolving or reading a fixture.
    enum Failure: Error, CustomStringConvertible {
        case notFound(String)
        case unreadable(String, underlying: Error)
        case undecodable(String, type: String, underlying: Error)

        var description: String {
            switch self {
            case let .notFound(name):
                return "Fixture no encontrado: \(name).json. ¿Está incluido en Copy Bundle Resources del target de tests?"
            case let .unreadable(name, error):
                return "Error leyendo fixture \(name).json: \(error)"
            case let .undecodable(name, type, error):
                return "Error decodificando \(name).json como \(type): \(error)"
            }
        }
    }

    private static let bundle = Bundle(for: BundleToken.self)

    /// Carga un archivo JSON del bundle de tests y devuelve su `Data`.
    ///
    /// Busca primero en el subdirectorio `Fixtures/` (cuando Xcode preserva la
    /// jerarquía de carpetas) y cae a la raíz del bundle (cuando la aplana).
    /// - Parameter name: nombre del archivo sin extensión, ej. `"login-response"`.
    static func load(_ name: String) throws -> Data {
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "json")

        guard let url else { throw Failure.notFound(name) }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw Failure.unreadable(name, underlying: error)
        }
    }

    /// Carga y decodifica un fixture JSON en un tipo `Decodable`.
    /// - Parameter name: nombre del archivo sin extensión.
    static func decode<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        let data = try load(name)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw Failure.undecodable(name, type: "\(T.self)", underlying: error)
        }
    }
}
