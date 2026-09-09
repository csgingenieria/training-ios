import AppIntents

/// «Ver mi posición», desde Siri o desde la búsqueda.
///
/// La app era invisible más allá de abrirla. Es un atajo, no una función nueva:
/// lleva a la misma pantalla que el widget y que la pestaña.
///
/// **No indexa nada en Spotlight**, y es deliberado: indexar significaría dejar
/// datos de una oposición en un índice del sistema que otras apps y la
/// búsqueda del dispositivo pueden leer. Un atajo que ABRE una pantalla no
/// necesita eso.
struct OpenStandingIntent: AppIntent {
    static var title: LocalizedStringResource = "Ver mi posición"

    static var description = IntentDescription(
        "Abre su puesto y su nota en la convocatoria seleccionada."
    )

    /// Abre la app: la pantalla necesita la sesión, y una respuesta hablada con
    /// el puesto de alguien la diría en voz alta donde haya quien escuche.
    static var openAppWhenRun: Bool { true }

    /// A dónde lleva. Sale de `DeepLink` para que haya UN mapa de destinos y no
    /// dos que se puedan desincronizar.
    static var route: DeepLink { .miPosicion }

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLinkInbox.shared.receive(Self.route)
        return .result()
    }
}

/// Lo que Siri ofrece sin que nadie configure nada.
struct TrainingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenStandingIntent(),
            phrases: ["Ver mi posición en \(.applicationName)"],
            shortTitle: "Mi posición",
            systemImageName: "trophy.fill"
        )
    }
}
