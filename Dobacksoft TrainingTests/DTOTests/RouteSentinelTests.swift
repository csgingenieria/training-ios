import Testing
import Foundation

@testable import Dobacksoft_Training

/// The backend publishes `"—"` in `route.id` and `route.label` when an attempt
/// has no route. Those attempts exist in production, and they have a grade.
///
/// Today it renders harmlessly by coincidence: `displayName` is
/// `name ?? label ?? id`, so it returns the dash, and the view's own
/// `?? "—"` fallback never fires. The two paths paint the same pixel.
///
/// It stops being harmless the moment anything GROUPS by route id, which is
/// exactly what the progress screen does: every route-less attempt would
/// collapse into a phantom route called «—», sitting next to `1A` and `2A1` as
/// if the candidate had driven it.
///
/// So the sentinel is turned into `nil` at decode time rather than filtered at
/// each use. A magic value that every consumer has to remember is a value that
/// some consumer will forget — and the one that forgets is the one that counts
/// routes, not the one that prints them.
///
/// This is step one of a two-step migration agreed with the backend: the client
/// tolerates both spellings first, and only then does the backend switch the
/// field to `null`. That order has no window in which either side is broken;
/// the reverse order does.
@Suite struct RouteSentinelTests {
    private func route(_ json: String) throws -> AttemptRouteDTO {
        try JSONDecoder().decode(AttemptRouteDTO.self, from: Data(json.utf8))
    }

    // MARK: - El centinela

    @Test func theDashSentinelDecodesAsNothing() throws {
        let route = try route(#"{"id": "—", "label": "—", "name": null, "categoria": null}"#)

        #expect(route.id == nil)
        #expect(route.label == nil)
        #expect(route.displayName == nil, "sin recorrido no hay nombre que enseñar")
    }

    /// The point of the whole change: a route-less attempt must not look like a
    /// route when something counts them.
    @Test func routelessAttemptsDoNotBecomeAPhantomRoute() throws {
        let sinRecorrido = try route(#"{"id": "—", "label": "—", "name": null, "categoria": null}"#)
        let otroSinRecorrido = try route(#"{"id": "—", "label": "—", "name": null, "categoria": null}"#)
        let real = try route(#"{"id": "2A1", "label": "2A1", "name": "Parque → Hoyo", "categoria": "EXAMEN"}"#)

        let codigos = Set([sinRecorrido, otroSinRecorrido, real].compactMap(\.id))

        #expect(codigos == ["2A1"], "los intentos sin recorrido no aportan código alguno")
    }

    /// `null` and `"—"` are the same thing said two ways, and the client must
    /// not be able to tell them apart — that is what lets the backend switch.
    @Test func nullAndTheSentinelAreIndistinguishable() throws {
        let conCentinela = try route(#"{"id": "—", "label": "—", "name": null, "categoria": null}"#)
        let conNulos = try route(#"{"id": null, "label": null, "name": null, "categoria": null}"#)

        #expect(conCentinela == conNulos)
    }

    @Test func aMissingKeyIsStillAccepted() throws {
        let vacio = try route("{}")

        #expect(vacio.id == nil)
        #expect(vacio.displayName == nil)
    }

    // MARK: - Lo que NO debe tocar

    @Test func aRealRouteSurvivesUntouched() throws {
        let real = try route(#"{"id": "2A1", "label": "2A1", "name": "Parque → Hoyo", "categoria": "EXAMEN"}"#)

        #expect(real.id == "2A1")
        #expect(real.label == "2A1")
        #expect(real.displayName == "Parque → Hoyo")
        #expect(real.isPractice == false)
    }

    /// Only the whole string counts as the sentinel. A code that merely
    /// contains a dash is a code: nilling it out would hide a real route.
    @Test func aCodeThatContainsADashIsStillACode() throws {
        for codigo in ["2A-1", "—2A1", "2A1—", "A—B"] {
            let r = try route(#"{"id": "\#(codigo)", "label": "\#(codigo)"}"#)
            #expect(r.id == codigo, "«\(codigo)» es un código, no el centinela")
        }
    }

    /// The hyphen-minus is not the sentinel the backend sends, and it could be
    /// a legitimate code. Only the em dash is treated as absence.
    @Test func onlyTheEmDashIsTheSentinel() throws {
        let guionCorto = try route(#"{"id": "-", "label": "-"}"#)

        #expect(guionCorto.id == "-")
    }

    /// The web pads its sentinels; a trimmed comparison costs nothing and
    /// covers `" — "` arriving from a formatted dict.
    @Test func surroundingWhitespaceDoesNotHideTheSentinel() throws {
        let conEspacios = try route(#"{"id": " — ", "label": "—  "}"#)

        #expect(conEspacios.id == nil)
        #expect(conEspacios.label == nil)
    }

    /// An empty string is absence too, and it reaches the same places.
    @Test func anEmptyStringIsAbsenceAsWell() throws {
        let vacia = try route(#"{"id": "", "label": "  "}"#)

        #expect(vacia.id == nil)
        #expect(vacia.label == nil)
    }

    /// `name` gets the same treatment even though today the backend sends it
    /// `null`. `displayName` reads `name` FIRST, so a sentinel arriving there
    /// would walk straight past the other two and put the dash back on screen —
    /// the whole defect, reintroduced through the one field left unguarded.
    @Test func theSentinelInTheNameIsResolvedToo() throws {
        let raro = try route(#"{"id": "2A1", "label": "2A1", "name": "—"}"#)

        #expect(raro.name == nil)
        #expect(raro.displayName == "2A1", "cae al código, que sí identifica algo")
    }

    /// `categoria` is deliberately NOT filtered: `isPractice` already answers
    /// «no lo sé» for any value it does not recognise, and running it through
    /// the sentinel would only add a second way to reach the same nil.
    @Test func theCategoryIsLeftAloneBecauseItAlreadyHandlesTheUnknown() throws {
        let raro = try route(#"{"id": "2A1", "categoria": "—"}"#)

        #expect(raro.isPractice == nil)
    }
}
