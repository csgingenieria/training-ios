import Foundation

/// Values the backend sends to mean «nothing», written as text.
///
/// The web portal formats its dictionaries for Jinja before serialising them,
/// so some fields arrive already dressed for a screen: `route.id` and
/// `route.label` carry `"—"` when the attempt has no route, and those attempts
/// exist in production with a grade. Other fields of the same contract send a
/// real `null` — `plaza` does — so the two spellings coexist.
///
/// The dash is harmless while it is only printed. It stops being harmless the
/// moment something GROUPS or COUNTS by the field: a route-less attempt becomes
/// a phantom route called «—» sitting beside `1A` and `2A1`, as if it had been
/// driven.
///
/// So it is resolved once, at decode time, instead of at each use. A magic
/// value that every consumer has to remember is a value that some consumer will
/// forget, and the one that forgets is the one counting routes, not the one
/// printing them.
nonisolated enum APISentinel {
    /// The em dash (U+2014) the portal uses. **Not** the hyphen-minus: that one
    /// is an ordinary character and could well be part of a real code.
    private static let absent = "—"

    /// The string, or `nil` when it says «nothing».
    ///
    /// Compares the WHOLE trimmed value. A code that merely contains a dash —
    /// `2A-1`, `A—B` — is a code, and nilling it out would hide a real route.
    static func text(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != absent else { return nil }

        // Se devuelve el valor ORIGINAL, no el recortado: recortar de paso
        // convertiría este ayudante en un saneador general y escondería que el
        // backend manda espacios, si algún día los manda en un dato de verdad.
        return value
    }
}
