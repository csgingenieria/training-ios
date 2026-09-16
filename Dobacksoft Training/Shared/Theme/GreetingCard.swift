import SwiftUI

/// El saludo con la inicial, arriba de la pantalla de inicio de cada rol.
///
/// Estaba escrito dos veces —en «Mi posición» y en el panel del instructor—
/// carácter a carácter salvo el subtítulo y el distintivo de rol. Una copia no
/// es un problema hasta que cambia el diseño: entonces se arregla en un sitio y
/// queda viva en el otro, y nadie lo nota porque cada rol solo ve el suyo.
///
/// El nombre y su inicial se leen aquí, no se pasan: quien dibuja el saludo
/// necesita exactamente eso, y hacer que cada pantalla lo extraiga por su
/// cuenta es lo que produjo las dos copias.
struct GreetingCard<Distintivo: View>: View {
    let name: String?
    let subtitle: String
    @ViewBuilder var distintivo: Distintivo

    /// La inicial del nombre, en mayúscula. Vacía si no hay nombre: un círculo
    /// sin letra se lee como «todavía no ha cargado», que es la verdad.
    private var inicial: String {
        (name?.prefix(1) ?? "").uppercased()
    }

    /// Solo el nombre de pila. Un saludo con los dos apellidos no es un saludo.
    private var nombreDePila: String {
        name?.components(separatedBy: " ").first ?? ""
    }

    var body: some View {
        HStack(spacing: Theme.spacing.base.value) {
            ZStack {
                Circle().fill(Color.brandTint)
                Text(inicial)
                    .font(.display(size: 22, weight: .bold, italic: true, relativeTo: .title2))
                    .foregroundStyle(Color.brand)
            }
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.spacing.xxs.value) {
                Text("Hola, \(nombreDePila)")
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                Text(subtitle)
                    .font(.metaCaption)
                    .foregroundStyle(Color.muted)
            }
            Spacer()
            distintivo
        }
        .cardStyle()
        // Una sola frase para VoiceOver: recorrer inicial, saludo y subtítulo
        // por separado no aporta nada y alarga el camino hasta el dato.
        .accessibilityElement(children: .combine)
    }
}

extension GreetingCard where Distintivo == EmptyView {
    /// Sin distintivo, que es el caso del aspirante: su rol no le dice nada que
    /// no sepa.
    init(name: String?, subtitle: String) {
        self.init(name: name, subtitle: subtitle) { EmptyView() }
    }
}

/// Lo que se saluda, separado de cómo se dibuja.
///
/// Existe para poder probar el saludo sin montar una vista: el nombre de pila y
/// la inicial son las dos decisiones con casos raros —nombre vacío, un solo
/// nombre, espacios de más— y son justo las que romperían el saludo sin que
/// ninguna prueba se enterase.
nonisolated enum GreetingCopy {
    static func initial(of name: String?) -> String {
        (name?.trimmingCharacters(in: .whitespaces).prefix(1) ?? "").uppercased()
    }

    static func firstName(of name: String?) -> String {
        name?.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: " ")
            .first(where: { !$0.isEmpty }) ?? ""
    }

    static func greeting(for name: String?) -> String {
        let pila = firstName(of: name)
        return pila.isEmpty ? "Hola" : "Hola, \(pila)"
    }
}
