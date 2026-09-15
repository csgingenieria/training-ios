import Foundation
import os

/// Lo último que se pudo leer, guardado para que un arranque sin cobertura
/// tenga algo que enseñar.
///
/// Todas las pantallas eran red-o-nada: un aspirante en el garaje de un parque,
/// sin señal, abría la app y no tenía absolutamente nada. El punto #3 arregló el
/// caso de sesión —un refresco que falla conserva lo que hay en pantalla— pero
/// un arranque en frío no tenía nada que conservar.
///
/// **Esto escribe en disco el puesto y la nota de una persona**, así que el
/// diseño no se inventa: sigue la doctrina que el widget ya tiene escrita.
///
/// 1. «No hay» y «no pude leer» son respuestas distintas. Colapsarlas le
///    presenta un fichero corrupto o una lectura antes del primer desbloqueo
///    como «no tiene datos» — una afirmación falsa sobre su cuenta.
/// 2. Va **por usuario**, porque un dispositivo se comparte. El iPad de un
///    instructor pasa de mano en mano y la posición de un aspirante no puede
///    leerse desde la sesión de otro.
/// 3. Se borra al cerrar sesión, junto con la instantánea del widget.
/// 4. No entrega cifras más viejas que el umbral de caducidad del widget. El
///    widget se niega a mostrar un puesto de 48 horas sin etiquetarlo; la app
///    no puede ser más permisiva con el mismo número.
nonisolated
struct LastGoodStore: Sendable {
    /// Qué se guarda. Cada clave es un fichero distinto.
    enum Key: String, Sendable, CaseIterable {
        case convocatorias
        case misConvocatorias
        case standing
        case progreso
    }

    /// Lo que se encontró.
    enum Result<T>: Sendable, Equatable where T: Sendable & Equatable {
        /// Utilizable, con la fecha en que se leyó.
        case presente(T, capturedAt: Date)
        /// Existe y es demasiado vieja para entregar cifras. Se dice CUÁNDO se
        /// leyó: «no hay datos» y «los suyos son de anteanoche» son cosas
        /// distintas que decirle a alguien.
        case caducada(capturedAt: Date)
        /// El contenedor es legible y no hay nada. Es el estado de todo primer
        /// arranque.
        case ausente
        /// No se pudo leer. **Nunca** se traduce como «no hay datos».
        case ilegible
    }

    private let directory: URL?

    /// El directorio se inyecta para poder probarlo. En la app es el contenedor
    /// privado, no el App Group: esto no lo lee ninguna otra superficie.
    init(directory: URL?) {
        self.directory = directory
    }

    static var appContainer: LastGoodStore {
        LastGoodStore(
            directory: try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("LastGood", isDirectory: true)
        )
    }

    // MARK: - Escribir

    @discardableResult
    func write<T: Encodable>(_ value: T, key: Key, userId: String, at now: Date = Date()) -> Bool {
        guard let folder = folderURL(userId: userId) else { return false }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let sobre = WriteEnvelope(capturedAt: now, value: value)
            let data = try JSONEncoder().encode(sobre)
            try data.write(to: folder.appendingPathComponent(key.rawValue + ".json"), options: [.atomic])
            // Sin respaldo en iCloud ni en el backup del dispositivo: es una
            // copia de conveniencia de datos bajo NDA, y no tiene por qué
            // sobrevivir a la app ni viajar a otro sitio.
            excludeFromBackup(folder)
            return true
        } catch {
            // Escribir es lo ÚLTIMO que puede romper una carga que salió bien.
            AppLog.api.error("No se pudo guardar el último dato de \(key.rawValue, privacy: .public)")
            return false
        }
    }

    // MARK: - Leer

    func read<T: Decodable & Sendable & Equatable>(
        _ type: T.Type,
        key: Key,
        userId: String,
        now: Date = Date()
    ) -> Result<T> {
        guard let file = fileURL(key: key, userId: userId) else { return .ilegible }
        guard FileManager.default.fileExists(atPath: file.path) else { return .ausente }

        do {
            let data = try Data(contentsOf: file)
            let sobre = try JSONDecoder().decode(ReadEnvelope<T>.self, from: data)
            let edad = now.timeIntervalSince(sobre.capturedAt)
            // `>=` y el mismo umbral que el widget: un solo criterio de
            // caducidad en el proyecto. Y una edad negativa —reloj corregido—
            // no es «del futuro»: se entrega, porque el dato es el que es.
            guard edad < SnapshotFreshness.expiryThreshold else {
                return .caducada(capturedAt: sobre.capturedAt)
            }
            return .presente(sobre.value, capturedAt: sobre.capturedAt)
        } catch {
            return .ilegible
        }
    }

    // MARK: - Borrar

    /// Todo lo de una sesión. Se llama al cerrar sesión.
    ///
    /// Solo lo de ESE usuario: en un dispositivo compartido, que uno cierre
    /// sesión y se lleve la caché de otro sería un defecto propio.
    func clear(userId: String) {
        guard let folder = folderURL(userId: userId) else { return }
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: - Rutas

    func fileURL(key: Key, userId: String) -> URL? {
        folderURL(userId: userId)?.appendingPathComponent(key.rawValue + ".json")
    }

    /// La carpeta de un usuario, o `nil` si el identificador no sirve.
    ///
    /// El identificador viene del backend, así que se valida: uno vacío pondría
    /// los datos en un cajón compartido que cualquier sesión leería, y uno con
    /// separadores o puntos suspensivos podría escribir fuera de su carpeta.
    private func folderURL(userId: String) -> URL? {
        guard let directory else { return nil }
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.contains("/"), !trimmed.contains(".."), trimmed != "." else { return nil }
        return directory.appendingPathComponent(trimmed, isDirectory: true)
    }

    private func excludeFromBackup(_ url: URL) {
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutable.setResourceValues(values)
    }
}

/// El dato con la fecha en que se leyó.
///
/// Dos formas y no una `Codable` genérica: escribir solo pide `Encodable` y
/// leer solo `Decodable`, y exigir las dos a la vez obligaría a cada DTO a
/// declarar una conformidad que no necesita. Los DTO de este proyecto son
/// `Decodable` a propósito —el cliente lee el contrato, no lo emite—, así que
/// para escribirlos hace falta lo mínimo.
nonisolated
private struct WriteEnvelope<T: Encodable>: Encodable {
    let capturedAt: Date
    let value: T
}

nonisolated
private struct ReadEnvelope<T: Decodable>: Decodable {
    let capturedAt: Date
    let value: T
}
