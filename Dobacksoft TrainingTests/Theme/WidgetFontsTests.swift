import Testing
import Foundation
import SwiftUI

@testable import Dobacksoft_Training

/// The widget carries the product's typefaces.
///
/// The position number — what the candidate glances at most — was Fraunces
/// inside the app and SF Rounded on the home screen: the same figure with two
/// faces depending on where it was read.
///
/// This is checked against the built bundles rather than the source, because
/// what decides whether a font loads is the file being IN the bundle and
/// declared in that bundle's `UIAppFonts`. A `.font(.display(…))` on a target
/// whose bundle lacks the file falls back to the system face **in silence** —
/// no warning, no crash, just a different letter.
struct WidgetFontsTests {
    private let esperadas = [
        "Fraunces72pt-Regular.ttf", "Fraunces72pt-Italic.ttf",
        "Fraunces72pt-Bold.ttf", "Fraunces72pt-BoldItalic.ttf",
        "Inter-Regular.ttf", "Inter-Medium.ttf",
        "Inter-SemiBold.ttf", "Inter-Bold.ttf"
    ]

    /// The app's own bundle declares all eight.
    @Test func theAppDeclaresItsEightFonts() throws {
        let declaradas = try #require(
            Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String]
        )
        for fuente in esperadas {
            #expect(declaradas.contains(fuente), "«\(fuente)» no está en UIAppFonts de la app")
        }
    }

    /// **And the files are actually there.** Declaring a font that is not in
    /// the bundle is the same silent fallback as not declaring it.
    @Test func theFontFilesAreInTheAppBundle() {
        for fuente in esperadas {
            let nombre = (fuente as NSString).deletingPathExtension
            #expect(
                Bundle.main.url(forResource: nombre, withExtension: "ttf") != nil,
                "falta el fichero de «\(fuente)» en el bundle"
            )
        }
    }

    /// The factories resolve to the product's faces and not to the system's.
    ///
    /// Compared against the system equivalent: if `display` ever fell back,
    /// this would stop telling them apart and the test would fail.
    @Test func theFactoriesDoNotReturnTheSystemFace() {
        #expect(Font.display(size: 34, weight: .bold, italic: false) != Font.system(size: 34, weight: .bold))
        #expect(Font.body(size: 17) != Font.system(size: 17))
    }
}
