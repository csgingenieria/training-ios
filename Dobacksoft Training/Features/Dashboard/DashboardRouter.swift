import SwiftUI

/// Las secciones del dashboard.
///
/// El `rawValue` es la identidad estable, no el rótulo: renombrar «Mi
/// posición» no puede hacer que todo el mundo pierda la sección restaurada.
nonisolated enum SidebarSection: String, Hashable, CaseIterable, Identifiable {
    case panel
    case convocatorias
    case miPosicion
    case miProgreso
    case perfil

    var id: String { rawValue }

    /// Compatibilidad con los identificadores de accesibilidad ya existentes
    /// (`sidebar.convocatorias`), de los que depende el recorrido de UI.
    var identifier: String { rawValue }

    var title: String {
        switch self {
        case .panel:         "Panel"
        case .convocatorias: "Convocatorias"
        case .miPosicion:    "Mi posición"
        case .miProgreso:    "Mi progreso"
        case .perfil:        "Perfil"
        }
    }

    var icon: String {
        switch self {
        case .panel:         "chart.bar.doc.horizontal"
        case .convocatorias: "list.bullet.rectangle"
        case .miPosicion:    "trophy.fill"
        case .miProgreso:    "chart.line.uptrend.xyaxis"
        case .perfil:        "person.crop.circle"
        }
    }

    /// Las secciones que este rol puede usar, en el orden en que se muestran.
    ///
    /// El aspirante no ve el panel del instructor, y el instructor no tiene
    /// posición ni progreso propios. `convocatorias` y `perfil` las tienen
    /// todos: sin una sección compartida no habría sitio seguro al que caer.
    static func available(isAdminLike: Bool, isStudent: Bool) -> [SidebarSection] {
        var sections: [SidebarSection] = []
        if isAdminLike { sections.append(.panel) }
        sections.append(.convocatorias)
        if isStudent {
            sections.append(.miPosicion)
            sections.append(.miProgreso)
        }
        sections.append(.perfil)
        return sections
    }
}

/// La sección visible y la pila de navegación de cada una.
///
/// Existe porque el dashboard tenía dos defectos que solo se ven moviendo el
/// dispositivo. `if sizeClass == .regular` cambiaba entre dos árboles de vistas
/// distintos, así que arrastrar un Split View o girar un iPhone Pro Max tiraba
/// todas las pantallas abiertas y sus view models. Y el panel de detalle del
/// iPad era un solo `NavigationStack` sin `path`, así que cambiar de sección
/// estando dentro de una convocatoria dejaba la pila de la sección anterior
/// puesta — justo lo contrario de lo que prometía el comentario de ese archivo.
///
/// Vive fuera de las vistas para que las dos lo compartan y para poder decir
/// qué hace: «cada sección conserva su pila» es una afirmación que un
/// comentario ya hizo una vez sin ser verdad.
@MainActor
@Observable
final class DashboardRouter {
    private let available: [SidebarSection]

    /// La sección visible. Se asigna directo desde los bindings de `TabView` y
    /// `List`; `select(_:)` es la vía con intención, que además hace pop.
    var section: SidebarSection {
        didSet {
            // Ni el binding de la lista ni el de las pestañas pueden ofrecer
            // una sección que no está en pantalla, pero el enlace del widget y
            // los atajos de teclado sí.
            guard !available.contains(section) else { return }
            section = oldValue
        }
    }

    private var paths: [SidebarSection: NavigationPath] = [:]

    init(isAdminLike: Bool, isStudent: Bool, restoring stored: String? = nil) {
        let available = SidebarSection.available(isAdminLike: isAdminLike, isStudent: isStudent)
        self.available = available

        // El aterrizaje sigue al rol: el instructor en su panel, el aspirante
        // en la lista. Antes lo hacía un `.onAppear` que reasignaba la
        // selección después del primer render, así que asomaba la pantalla
        // equivocada.
        let landing = available.first ?? .convocatorias

        // Una sección restaurada que el rol no puede usar se acota, no se
        // muestra: `@SceneStorage` sobrevive al relanzamiento, y el iPad de un
        // instructor restaurando `.panel` para el aspirante que entra después
        // abriría una pantalla cuyos endpoints le rechazan.
        if let stored, let restored = SidebarSection(rawValue: stored), available.contains(restored) {
            self.section = restored
        } else {
            self.section = landing
        }
    }

    // MARK: - Las pilas

    func path(for section: SidebarSection) -> NavigationPath {
        paths[section] ?? NavigationPath()
    }

    /// El `binding` que consume cada `NavigationStack`.
    ///
    /// Tiene que escribir de vuelta: una pila que lee el camino pero no lo
    /// guarda perdería cada push en cuanto SwiftUI recreara la vista, que es
    /// exactamente el defecto que esto viene a arreglar.
    func pathBinding(for section: SidebarSection) -> Binding<NavigationPath> {
        Binding(
            get: { self.path(for: section) },
            set: { self.paths[section] = $0 }
        )
    }

    func push(_ value: some Hashable, in section: SidebarSection) {
        var path = self.path(for: section)
        path.append(value)
        paths[section] = path
    }

    func popToRoot(_ section: SidebarSection) {
        paths[section] = NavigationPath()
    }

    /// Elegir sección.
    ///
    /// **No hace pop, y es deliberado.** Hacía pop a la raíz al reelegir la
    /// sección visible, imitando el «toca la pestaña actual para volver
    /// arriba» de la plataforma. Esa comodidad costaba navegación:
    /// `TabView(selection:)` y `List(selection:)` escriben su binding, y una
    /// escritura del valor que ya estaba —que SwiftUI hace al reconciliar, no
    /// solo al tocar— llegaba aquí y vaciaba la pila. Una pantalla que la
    /// persona había abierto desaparecía sola.
    ///
    /// Se vio como un fallo intermitente del recorrido contra staging: la
    /// ficha del recorrido «no abría» desde «Mi progreso», a veces. Sí abría, y
    /// algo la tiraba.
    ///
    /// Volver a la raíz sigue siendo posible con `popToRoot`, pidiéndolo — y
    /// nunca como efecto secundario de un binding.
    func select(_ section: SidebarSection) {
        guard available.contains(section) else { return }
        self.section = section
    }
}
