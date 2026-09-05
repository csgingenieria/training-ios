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

    /// Fondo de página estándar — `paper`. Para pantallas que NO usan `Form`/`List`.
    func pageBackground() -> some View {
        self.background(Color.paper.ignoresSafeArea())
    }
}

// MARK: - Status badge

enum BadgeKind {
    case neutral, brand, success, warning, danger

    var foreground: Color {
        switch self {
        case .neutral: return .inkSecondary
        case .brand:   return .brand
        case .success: return .success
        case .warning: return .warning
        case .danger:  return .danger
        }
    }

    var background: Color {
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
            .foregroundStyle(.white)
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
