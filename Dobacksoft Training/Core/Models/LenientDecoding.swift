import Foundation

/// Lecturas que no tumban la respuesta cuando el tipo no es el esperado.
///
/// La regla ya estaba escrita en este repo para `SyncResultDTO` —«un tipo
/// inesperado no puede tumbar la respuesta»— y no se había aplicado al resto.
/// Costó el mapa entero de un intento: `severity` llegaba como texto en un
/// evento y el aspirante perdía el trazado de su vuelta, el recorrido y los
/// demás eventos por un campo con el que el mapa no dibuja nada.
///
/// **Devuelven `nil`, no lanzan.** Eso es lo que las hace útiles: un campo que
/// no se entiende es un campo que no consta, y las pantallas ya saben decir
/// que un dato no consta. Lo que no sabían hacer era sobrevivir a él.
///
/// No usar donde el campo sea estructural. Si sin él la respuesta no significa
/// nada, tiene que fallar: tolerar una identidad ausente daría objetos que se
/// confunden entre sí.
nonisolated extension KeyedDecodingContainer {
    /// Un número que puede llegar como número o como texto.
    ///
    /// Una etiqueta como «MODERADO» da `nil`: **nunca se inventa una cifra a
    /// partir de una palabra**, aunque el backend tenga una tabla que las
    /// relacione. Esa conversión es suya, y hacerla aquí afirmaría una
    /// precisión que el dato no trae.
    func lenientDouble(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        guard let text = try? decodeIfPresent(String.self, forKey: key) else { return nil }
        // Sin traducir comas: «1,234» es mil doscientos treinta y cuatro en un
        // sitio y uno coma doscientos treinta y cuatro en otro, y adivinar cuál
        // sería inventarse el dato. JSON manda punto.
        return Double(text.trimmingCharacters(in: .whitespaces))
    }

    func lenientInt(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return Int(value) }
        guard let text = try? decodeIfPresent(String.self, forKey: key) else { return nil }
        return Int(text.trimmingCharacters(in: .whitespaces))
    }

    /// Un texto que puede llegar como texto o como número.
    func lenientString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(value) }
        return nil
    }

    /// Un booleano que puede llegar como booleano, como 0/1 o como «true».
    func lenientBool(forKey key: Key) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value != 0 }
        guard let text = try? decodeIfPresent(String.self, forKey: key) else { return nil }
        switch text.trimmingCharacters(in: .whitespaces).lowercased() {
        case "true", "1", "sí", "si": return true
        case "false", "0", "no":      return false
        default:                      return nil
        }
    }
}
