import Testing
import UIKit

@testable import Dobacksoft_Training

/// Freezes the contrast of text on the brand colour, in both appearances.
///
/// `BrandPrimaryButtonStyle` hard-coded `.white`. In light mode `Brand` is a
/// navy (#1E3A8A) and white on it is 10.36:1 — excellent. In dark mode `Brand`
/// becomes a light periwinkle (#7C9CFF) and white on it is **2.61:1**, below
/// even the 3:1 that WCAG allows for large text. That is «Iniciar sesión» and
/// every «Reintentar» in the app, unreadable for the candidate who runs their
/// phone in dark mode — which, on a night shift, is most of them.
///
/// The check resolves the colour the way the system does, against a trait
/// collection, instead of parsing `Contents.json`. Parsing the file would prove
/// what the repository says; resolving proves what the button paints, which is
/// the thing that has to be legible.
@Suite struct BrandContrastTests {
    /// WCAG 2.1 minimum for body text. Large text would allow 3:1, but the
    /// button label is 16 pt semibold — not large by the standard's definition
    /// (18 pt regular / 14 pt bold).
    private static let aaMinimum = 4.5

    /// The button dims its background to 85 % while pressed, so the label's
    /// contrast drops exactly when a finger is on it. Whatever is behind
    /// composites through, and on the login screen that is `Paper`.
    private static let pressedOpacity = 0.85

    // MARK: - Casos

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func theBrandButtonLabelMeetsAAAtRest(style: UIUserInterfaceStyle) throws {
        let brand = try resolved("Brand", style)
        let onBrand = try resolved("OnBrand", style)

        let ratio = contrastRatio(onBrand, over: brand)

        #expect(
            ratio >= Self.aaMinimum,
            "OnBrand sobre Brand en \(name(style)) da \(rounded(ratio)):1, por debajo de \(Self.aaMinimum):1"
        )
    }

    /// Pressed is the tightest case: in dark mode it lands at 4.80:1, above the
    /// threshold but with little room. If a future palette change pushes it
    /// under, this is where it shows up.
    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func theBrandButtonLabelMeetsAAWhilePressed(style: UIUserInterfaceStyle) throws {
        let brand = try resolved("Brand", style)
        let onBrand = try resolved("OnBrand", style)
        let paper = try resolved("Paper", style)

        let pressed = composite(brand, alpha: Self.pressedOpacity, over: paper)
        let ratio = contrastRatio(onBrand, over: pressed)

        #expect(
            ratio >= Self.aaMinimum,
            "pulsado en \(name(style)) da \(rounded(ratio)):1, por debajo de \(Self.aaMinimum):1"
        )
    }

    /// The defect itself, kept as a case so nobody reintroduces `.white` by
    /// reasoning that it «looked fine»: it did, in light mode only.
    @Test func plainWhiteWouldStillFailInDarkMode() throws {
        let brand = try resolved("Brand", .dark)

        let ratio = contrastRatio(.white, over: brand)

        #expect(
            ratio < Self.aaMinimum,
            "si `Brand` en oscuro ya admite blanco (\(rounded(ratio)):1), OnBrand sobra y este archivo también"
        )
    }

    // MARK: - Utilidades

    private func resolved(_ name: String, _ style: UIUserInterfaceStyle) throws -> UIColor {
        let color = try #require(
            UIColor(named: name, in: .main, compatibleWith: nil),
            "el catálogo de la app no expone «\(name)»"
        )
        return color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }

    private func name(_ style: UIUserInterfaceStyle) -> String {
        style == .dark ? "modo oscuro" : "modo claro"
    }

    private func rounded(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// Relative luminance, WCAG 2.1 §relative-luminance.
    private func luminance(_ color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        func channel(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    private func contrastRatio(_ foreground: UIColor, over background: UIColor) -> Double {
        let a = luminance(foreground), b = luminance(background)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// `foreground` at `alpha` painted over `background`, which is what
    /// `.opacity()` does at render time.
    private func composite(_ foreground: UIColor, alpha: Double, over background: UIColor) -> UIColor {
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        foreground.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        background.getRed(&br, green: &bg, blue: &bb, alpha: &ba)

        let mix = { (f: CGFloat, b: CGFloat) in f * CGFloat(alpha) + b * (1 - CGFloat(alpha)) }
        return UIColor(
            red: mix(fr, br),
            green: mix(fg, bg),
            blue: mix(fb, bb),
            alpha: 1
        )
    }
}
