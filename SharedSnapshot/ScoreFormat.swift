import Foundation

/// Cómo se escribe una nota en pantalla.
///
/// La app usaba `String(format: "%.2f", …)` en once sitios, que da dos
/// decimales y **punto** decimal. En castellano el separador es la coma, y el
/// portal web —que el cliente ya tiene aceptado y que el manual de instructor
/// documenta con capturas— escribe «8,5» y «4,75». Un aspirante que ve «8.50»
/// en el móvil y «8,5» en el portal no está viendo el mismo sistema.
///
/// La precisión no es uniforme, y en el portal es deliberada:
///
/// - la nota de **un intento** lleva un decimal (`%.1f` en `resultados.html`
///   y `alumno.html`);
/// - las notas **agregadas** —la media oficial y la media de lo conducido—
///   llevan dos (`%.2f` para `nota_media` y `nota_de_lo_conducido`).
///
/// Vive en `SharedSnapshot/` porque el widget también pinta la nota y tenía
/// sus propios tres `String(format:)`. Solo depende de Foundation, que es la
/// condición para estar en este grupo.
///
/// La coma va fija, no vía `Locale.current`: toda la interfaz de esta app está
/// escrita en castellano sin localizar, así que un teléfono en inglés
/// escribiría «8.5» rodeado de etiquetas en español. El idioma de la app no
/// depende del ajuste del dispositivo y el número tampoco debe depender.
nonisolated enum ScoreFormat {
    /// Nota de un intento concreto: «8,5».
    static func attempt(_ value: Double) -> String {
        spanish(value, decimals: 1)
    }

    /// Nota agregada —media oficial, media de lo conducido—: «4,75».
    ///
    /// Dos decimales porque un promedio sobre diez recorridos cae en cuartos
    /// (4,75) y redondearlo a 4,8 cambiaría el número que el aspirante ve en el
    /// portal y, si recurre, en el acta.
    static func aggregate(_ value: Double) -> String {
        spanish(value, decimals: 2)
    }

    /// Componente del desglose: dos decimales, igual que el peso con el que se
    /// compara («2,21 / 3,75»).
    static func component(_ value: Double) -> String {
        spanish(value, decimals: 2)
    }

    /// Para VoiceOver: «8,5 sobre 10».
    ///
    /// Una cifra a secas no dice sobre cuánto, y la nota vive al lado de un
    /// puesto, de un código de recorrido y de un número de participantes: sin
    /// la escala, quien escucha la pantalla no sabe cuál de los cuatro números
    /// le acaban de leer.
    static func spoken(_ value: Double, decimals: Int) -> String {
        "\(spanish(value, decimals: decimals)) sobre 10"
    }

    private static func spanish(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value).replacingOccurrences(of: ".", with: ",")
    }
}
