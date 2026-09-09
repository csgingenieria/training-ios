import Foundation

/// Los destinos a los que se puede llegar desde fuera de la app.
///
/// Hoy solo uno: el widget. Decía al aspirante que abriera «Mi posición» y el
/// toque abría Convocatorias, porque no había esquema de URL, ni `widgetURL`,
/// ni `onOpenURL` en todo el proyecto. La instrucción era cierta y el toque la
/// contradecía.
///
/// **El análisis vive en la app, nunca en `SharedSnapshot`.** El widget solo
/// escribe la URL; interpretarla es decidir navegación, y eso es del target que
/// tiene sesión y roles.
nonisolated enum DeepLink: Hashable, Sendable {
    case miPosicion

    /// El esquema propio, declarado en `CFBundleURLTypes`.
    ///
    /// Sale de `SnapshotLink` —el código compartido con el widget— para que la
    /// cadena exista una sola vez. Repetida a los dos lados de la frontera, el
    /// widget acabaría abriendo una URL que la app dejó de reconocer.
    static let scheme = SnapshotLink.scheme

    init?(url: URL) {
        // Comparación insensible a mayúsculas: RFC 3986 dice que el esquema lo
        // es, y el sistema entrega lo que haya escrito quien llamó. Rechazar un
        // esquema con otra caja sería tirar un enlace que es nuestro.
        guard url.scheme?.lowercased() == Self.scheme else { return nil }

        // Por HOST exacto, no por «contiene»: si no, cualquier cadena con la
        // palabra dentro resolvería, y `?volver=mi-posicion` navegaría.
        switch url.host()?.lowercased() {
        case "mi-posicion":
            self = .miPosicion
        default:
            // Un destino desconocido NO cae a una pantalla por defecto: eso
            // haría que una errata pareciera un enlace que funciona, y que un
            // enlace de un widget más nuevo aterrizara en cualquier sitio en
            // vez de ignorarse.
            return nil
        }
    }

    /// La URL que escribe el widget.
    var url: URL? { URL(string: "\(Self.scheme)://\(host)") }

    private var host: String {
        switch self {
        case .miPosicion: "mi-posicion"
        }
    }

    /// La sección del dashboard a la que lleva.
    ///
    /// Sale de `SidebarSection` para que haya UNA lista de destinos y no dos.
    /// Que el rol pueda usarla o no lo decide el router, que ya sabe acotar.
    var section: SidebarSection {
        switch self {
        case .miPosicion: .miPosicion
        }
    }
}

/// Guarda el enlace hasta que haya alguien que pueda atenderlo.
///
/// Un arranque en frío desde el widget entrega la URL mientras todavía está la
/// pantalla de carga y el dashboard no existe. Sin sitio donde esperar, el
/// enlace se pierde en silencio — el mismo defecto que no tener enlace, solo
/// más difícil de notar.
@MainActor
@Observable
final class DeepLinkInbox {
    /// Compartido para que un `AppIntent` pueda dejar su destino aquí.
    ///
    /// Un intent corre fuera de la jerarquía de vistas y no tiene acceso al
    /// entorno de SwiftUI, así que necesita un buzón al que llegar. `RootView`
    /// usa este mismo, no uno propio: dos buzones significarían que el enlace
    /// del widget y el de Siri se pierden uno al otro.
    static let shared = DeepLinkInbox()

    private(set) var pending: DeepLink?

    /// Un destino ya resuelto, de un `AppIntent` que no pasa por una URL.
    func receive(_ link: DeepLink) {
        pending = link
    }

    func receive(_ url: URL) {
        // Una URL que no es nuestra no se convierte en enlace y tampoco
        // desaloja al que estuviera esperando.
        guard let link = DeepLink(url: url) else { return }
        pending = link
    }

    /// Se atiende UNA vez.
    ///
    /// Un enlace que se quedara pendiente arrastraría al aspirante de vuelta a
    /// «Mi posición» cada vez que el dashboard se reconstruye: en cada giro, en
    /// cada arrastre de Split View.
    func consume() -> DeepLink? {
        defer { pending = nil }
        return pending
    }
}
