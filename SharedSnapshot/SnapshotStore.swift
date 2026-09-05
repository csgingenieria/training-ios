import Foundation
import os

/// Registro propio del módulo compartido.
///
/// No usa `AppLog` a propósito: este fichero lo compilan varios targets y
/// `AppLog` solo existe en el de la app.
private let snapshotLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.dobacksoft.training",
    category: "snapshot"
)

/// Resultado de intentar leer la instantánea.
///
/// La distinción entre «no hay» y «no pude leer» es el corazón del diseño.
/// Colapsarlas hace que un entitlement mal firmado, un fichero corrupto o una
/// lectura antes del primer desbloqueo se le presenten al usuario como «no ha
/// iniciado sesión» — una afirmación falsa sobre su cuenta, tan falsa como el
/// puesto inventado que este trabajo viene a eliminar, solo que menos vistosa.
enum SnapshotReadResult: Sendable, Equatable {
    /// No se pudo leer. **Nunca** se traduce como «inicie sesión».
    case ilegible(Reason)
    /// El contenedor es legible y no hay instantánea: no hay sesión.
    case ausente
    case presente(StandingSnapshot)

    enum Reason: String, Sendable {
        /// El contenedor del App Group no está disponible: entitlement ausente
        /// o grupo sin registrar.
        case sinContenedor
        /// El fichero existe pero no se pudo leer (protección de datos antes
        /// del primer desbloqueo, permisos).
        case noSePudoLeer
        /// El contenido no es una instantánea válida.
        case corrupto
        /// Escrito por una versión más nueva de la app.
        case versionDesconocida
    }
}

/// Lee y escribe la instantánea en el contenedor compartido.
///
/// La app escribe; las superficies secundarias solo leen. Un lector **nunca**
/// borra ni reescribe, ni siquiera para purgar algo caducado.
struct SnapshotStore: Sendable {
    /// Identificador del App Group.
    ///
    /// Sigue la convención de los bundle ids del proyecto. **Debe registrarse
    /// en el portal de Apple Developer y añadirse al entitlements de la app y
    /// del widget.** Mientras no lo esté, `containerURL` devuelve `nil`, la
    /// lectura da `.ilegible(.sinContenedor)` y las superficies dicen que no
    /// hay datos: degrada sin mentir.
    static let appGroupIdentifier = "group.Com.Dobacksoft-Training"

    private static let fileName = "standing-snapshot.json"

    /// Directorio base. Inyectable para poder probar sin App Group.
    private let directory: URL?

    /// Usa el contenedor compartido real.
    init() {
        self.directory = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)

        if directory == nil {
            snapshotLog.error(
                "Contenedor del App Group no disponible (\(Self.appGroupIdentifier, privacy: .public)). La vista rápida no mostrará datos."
            )
        }
    }

    /// Usa un directorio concreto. Para pruebas.
    init(directory: URL?) {
        self.directory = directory
    }

    private var fileURL: URL? {
        directory?.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    // MARK: - Escritura (solo la app)

    @discardableResult
    func write(_ snapshot: StandingSnapshot) -> Bool {
        guard let fileURL else { return false }
        do {
            let data = try StandingSnapshot.encoder.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            snapshotLog.error("No se pudo escribir la instantánea: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    /// Borra la instantánea. Se llama al cerrar sesión: sin esto, alguien que
    /// ha salido seguiría viendo su puesto en la pantalla de inicio.
    @discardableResult
    func clear() -> Bool {
        guard let fileURL else { return false }
        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch CocoaError.fileNoSuchFile {
            return true // No había nada que borrar.
        } catch {
            snapshotLog.error("No se pudo borrar la instantánea: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    // MARK: - Lectura

    func read() -> SnapshotReadResult {
        guard let fileURL else { return .ilegible(.sinContenedor) }

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .ausente }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            // El fichero está pero no se deja leer: típicamente, arranque en
            // frío antes del primer desbloqueo. No es ausencia de sesión.
            return .ilegible(.noSePudoLeer)
        }

        guard let snapshot = try? StandingSnapshot.decoder.decode(StandingSnapshot.self, from: data) else {
            return .ilegible(.corrupto)
        }

        guard snapshot.schemaVersion <= StandingSnapshot.currentSchemaVersion else {
            // Escrito por una app más nueva. Adivinar el formato sería inventar.
            return .ilegible(.versionDesconocida)
        }

        return .presente(snapshot)
    }
}
