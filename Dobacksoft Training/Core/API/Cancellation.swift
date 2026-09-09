import Foundation

/// Si un error es una cancelación y no un fallo de verdad.
///
/// Existe porque hay **dos** formas de que llegue y tratar solo una deja el
/// defecto a medias: `CancellationError` de Swift Concurrency, y
/// `URLError(.cancelled)` de `URLSession` cuando la tarea se cancela con la
/// petición en vuelo. La segunda es la que se ve al cambiar de convocatoria a
/// media carga.
nonisolated extension Error {
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let url = self as? URLError, url.code == .cancelled { return true }
        return false
    }
}
