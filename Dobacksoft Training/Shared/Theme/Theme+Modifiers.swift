import SwiftUI

// Modifiers y componentes reusables que componen el design system.
// Uso:
//   .cardStyle()                       → fondo elevado + radio + sombra suave
//   .themedShadow(.small)              → solo sombra
//   .pageBackground()                  → fondo paper a pantalla completa
//   .statusBadge(.success)             → píldora coloreada para estados
//   .brandPrimaryButtonStyle()         → estilo botón primario

extension View {
    /// Card: fondo `paperElevated`, radio `medium`, sombra `small`.
    func cardStyle(padding: CGFloat = Theme.spacing.base.value) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                    .fill(Color.paperElevated)
            )
            .themedShadow(.small)
    }

    /// Sombra del design system aplicada como modifier.
    func themedShadow(_ kind: Theme.shadow) -> some View {
        self.shadow(color: kind.color, radius: kind.radius, x: 0, y: kind.y)
    }

    /// Acota el contenido a un ancho legible y lo centra.
    ///
    /// En el panel de detalle de un iPad las tarjetas, los pares de métricas y
    /// las notas al pie se estiraban a 700-800 pt: es el aspecto de teléfono
    /// estirado que el proyecto descartó. 680 pt es donde una línea de texto
    /// deja de costar un barrido de ojos.
    func readableWidth(_ max: CGFloat = 680) -> some View {
        frame(maxWidth: max).frame(maxWidth: .infinity)
    }

    /// Fondo de página estándar — `paper`. Para pantallas que NO usan `Form`/`List`.
    func pageBackground() -> some View {
        self.background(Color.paper.ignoresSafeArea())
    }
}

// MARK: - Status badge

nonisolated enum BadgeKind {
    case neutral, brand, success, warning, danger

    // Los símbolos de color los genera Xcode desde el catálogo de assets y
    // salen aislados al MainActor, así que estas dos propiedades lo están
    // también. El tipo sigue siendo `nonisolated` para que su conformidad
    // sintetizada a Equatable no lo esté: eso era lo que producía avisos
    // «error en modo Swift 6» en cada comparación de insignia.
    @MainActor var foreground: Color {
        switch self {
        case .neutral: return .inkSecondary
        case .brand:   return .brand
        case .success: return .success
        case .warning: return .warning
        case .danger:  return .danger
        }
    }

    @MainActor var background: Color {
        switch self {
        case .neutral: return .paperElevated
        case .brand:   return .brandTint
        case .success: return .successTint
        case .warning: return .warningTint
        case .danger:  return .dangerTint
        }
    }
}

struct StatusBadge: View {
    let text: String
    let kind: BadgeKind

    var body: some View {
        Text(text)
            .font(.body(size: 11, weight: .semibold, relativeTo: .caption2))
            .foregroundStyle(kind.foreground)
            .padding(.horizontal, Theme.spacing.sm.value)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous).fill(kind.background)
            )
            .accessibilityElement(children: .combine)
    }
}

// MARK: - Brand primary button style

struct BrandPrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body(size: 16, weight: .semibold, relativeTo: .body))
            // `.white` fijo, no: en modo oscuro `Brand` es #7C9CFF y el blanco
            // encima da 2,61:1 — muy por debajo del 4,5:1 que exige AA, incluso
            // del 3:1 de texto grande. Es el botón de «Iniciar sesión» y el de
            // cada «Reintentar». `OnBrand` sigue la apariencia: blanco en claro
            // (10,36:1), #0B1A4A en oscuro (6,39:1).
            .foregroundStyle(Color.onBrand)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 14)
            .padding(.horizontal, Theme.spacing.lg.value)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius.medium.value, style: .continuous)
                    .fill(Color.brand.opacity(configuration.isPressed ? 0.85 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.motion.fast, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BrandPrimaryButtonStyle {
    static var brandPrimary: BrandPrimaryButtonStyle { BrandPrimaryButtonStyle() }
    static func brandPrimary(fullWidth: Bool) -> BrandPrimaryButtonStyle {
        BrandPrimaryButtonStyle(fullWidth: fullWidth)
    }
}
