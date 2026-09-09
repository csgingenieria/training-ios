import SwiftUI

// Theme — sistema de diseño nativo iOS para Dobacksoft Training.
//
// Source of truth:
//   /Users/antoniohermoso/repos/training/app/static/css/tokens.css
//   /Users/antoniohermoso/repos/training/docs/superpowers/specs/2026-05-15-frontend-redesign-design.md
//
// Divergencias intencionales respecto al web:
//   - Dark mode: iOS sí (HIG); web no.
//   - Iconos: SF Symbols (web usa Phosphor).
//   - Botones: nativos `.borderedProminent` con tinte brand; el web tiene clases custom.
//
// Uso:
//   Text("Training").font(.appTitle).foregroundStyle(Color.brand)
//   .padding(Theme.spacing.md)
//   .background(.paperElevated, in: RoundedRectangle(cornerRadius: Theme.radius.medium))
//
// No instanciar. Todos los miembros son estáticos por namespace.

enum Theme {

    enum spacing {
        /// `xxs` son los 2 pt que estaban repartidos como literal por seis
        /// sitios —el hueco entre una cifra y su rótulo— y que nadie podía
        /// cambiar de una vez.
        case xxs, xs, sm, md, base, lg, xl, xxl, xxxl

        var value: CGFloat {
            switch self {
            case .xxs:  return 2
            case .xs:   return 4
            case .sm:   return 8
            case .md:   return 12
            case .base: return 16
            case .lg:   return 24
            case .xl:   return 32
            case .xxl:  return 48
            case .xxxl: return 64
            }
        }
    }

    enum radius {
        case none, small, medium, full

        var value: CGFloat {
            switch self {
            case .none:   return 0
            case .small:  return 4
            case .medium: return 8
            case .full:   return 999
            }
        }
    }

    enum shadow {
        case small, medium, large

        var color: Color { Color.black.opacity(opacityValue) }
        var radius: CGFloat {
            switch self {
            case .small:  return 2
            case .medium: return 12
            case .large:  return 32
            }
        }
        var y: CGFloat {
            switch self {
            case .small:  return 1
            case .medium: return 4
            case .large:  return 12
            }
        }
        private var opacityValue: Double {
            switch self {
            case .small:  return 0.04
            case .medium: return 0.06
            case .large:  return 0.08
            }
        }
    }

    enum motion {
        static let fast: Animation = .easeOut(duration: 0.12)
        static let base: Animation = .easeOut(duration: 0.18)
        static let slow: Animation = .easeInOut(duration: 0.22)

        // Equivalentes a --ease-out-strong / --ease-in-out-strong del web.
        static let outStrong: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.22)
        static let inOutStrong: Animation = .timingCurve(0.77, 0, 0.175, 1, duration: 0.22)
    }
}
