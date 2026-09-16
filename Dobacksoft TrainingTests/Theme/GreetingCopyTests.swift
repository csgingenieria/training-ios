import Testing
import Foundation

@testable import Dobacksoft_Training

/// El saludo de la pantalla de inicio.
///
/// Estaba escrito dos veces —«Mi posición» y el panel del instructor— idéntico
/// salvo el subtítulo, y en ninguna de las dos había forma de probarlo: vivía
/// dentro del `body`. Extraído a `GreetingCopy`, lo que se puede comprobar es
/// justo lo que rompería el saludo en manos de alguien: un nombre con espacios
/// de más, un nombre de una sola palabra, o ninguno.
@MainActor
struct GreetingCopyTests {
    @Test func laInicialEsLaPrimeraLetraEnMayuscula() {
        #expect(GreetingCopy.initial(of: "ana muñoz") == "A")
        #expect(GreetingCopy.initial(of: "Ana Muñoz") == "A")
    }

    /// Un nombre con espacio delante daría un círculo vacío, que se lee como
    /// «no ha cargado». El espacio no es un nombre.
    @Test func laInicialIgnoraLosEspaciosDeMas() {
        #expect(GreetingCopy.initial(of: "  Ana Muñoz") == "A")
        #expect(GreetingCopy.firstName(of: "  Ana Muñoz") == "Ana")
    }

    @Test func soloSeSaludaPorElNombreDePila() {
        #expect(GreetingCopy.firstName(of: "Ana Muñoz Pérez") == "Ana")
        #expect(GreetingCopy.greeting(for: "Ana Muñoz Pérez") == "Hola, Ana")
    }

    @Test func unNombreDeUnaSolaPalabraSirveIgual() {
        #expect(GreetingCopy.firstName(of: "Ana") == "Ana")
        #expect(GreetingCopy.greeting(for: "Ana") == "Hola, Ana")
    }

    /// **Sin nombre no se saluda a una coma.** «Hola, » con la coma colgando es
    /// el clásico de una plantilla sin comprobar, y aquí lo vería alguien
    /// mirando su propia nota.
    @Test func sinNombreElSaludoNoDejaUnaComaColgando() {
        #expect(GreetingCopy.greeting(for: nil) == "Hola")
        #expect(GreetingCopy.greeting(for: "") == "Hola")
        #expect(GreetingCopy.greeting(for: "   ") == "Hola")
        #expect(GreetingCopy.initial(of: nil) == "")
        #expect(GreetingCopy.initial(of: "   ") == "")
    }

    /// Y el control del anterior: **con nombre sí lleva coma**. Sin esto, un
    /// saludo que nunca salude a nadie pasaría las pruebas.
    @Test func conNombreSiLlevaComa() {
        #expect(GreetingCopy.greeting(for: "Ana").contains(","))
    }

    /// Artículo 22 también aquí: el saludo no adjetiva a quien saluda.
    @Test func elSaludoNoPronunciaUnVeredicto() {
        let prohibidas = ["apto", "aprobad", "suspens", "admitid", "excluid"]
        for nombre in ["Ana", nil, ""] {
            let saludo = GreetingCopy.greeting(for: nombre).lowercased()
            for prohibida in prohibidas {
                #expect(!saludo.contains(prohibida))
            }
        }
    }
}
