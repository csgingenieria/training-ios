import Foundation

/// Un reloj que el test mueve a mano y el código bajo prueba lee.
///
/// **Existe porque un `var` capturado por una clausura `@Sendable` es una
/// carrera de datos**, no una comodidad de test. Los view models reciben
/// `now: @Sendable () -> Date` y lo llaman desde donde les toca; escribir
///
///     var ahora = t0
///     let vm = StandingViewModel(api: api, now: { ahora })
///     ahora = despues
///
/// compila en el modo actual del lenguaje y en modo Swift 6 es un error. Con
/// razón: la clausura puede ejecutarse en otro hilo mientras el test escribe
/// la variable, y lo que se lea entonces no está definido.
///
/// **Que los tests pasaran no dice nada.** Una carrera que no se manifiesta
/// sigue siendo una carrera, y los tests de un view model asíncrono son justo
/// donde menos cuesta que se manifieste — un día, en una máquina cargada, en
/// una corrida que nadie sabrá reproducir.
///
/// La cerradura no es ceremonia: es lo que hace que `now` devuelva siempre un
/// valor que alguien escribió entero.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var instante: Date

    init(_ instante: Date) {
        self.instante = instante
    }

    /// Lo que lee el código bajo prueba. Se pasa como `now:`.
    var now: @Sendable () -> Date {
        { [self] in lock.withLock { instante } }
    }

    /// Mueve el reloj. El nombre dice lo que pasa: el tiempo avanza, no «se
    /// asigna una variable».
    func advance(to instante: Date) {
        lock.withLock { self.instante = instante }
    }
}
