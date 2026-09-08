import Foundation

/// La URL que el widget pone en su toque.
///
/// Vive aquí porque la **escribe** el widget y la **lee** la app, y una cadena
/// repetida a los dos lados de la frontera es exactamente lo que deriva: el
/// widget seguiría abriendo una URL que la app dejó de reconocer, en silencio y
/// sin que ningún test de un solo target lo notara.
///
/// Aquí solo está la construcción. **Interpretarla es de la app** (`DeepLink`):
/// decidir a qué pantalla se va depende de la sesión y del rol, y de eso este
/// código compartido no sabe nada ni debe saber.
nonisolated enum SnapshotLink {
    static let scheme = "dobacksoft-training"

    /// «Mi posición», la pantalla que además republica la instantánea.
    static let miPosicion = URL(string: "\(scheme)://mi-posicion")
}
