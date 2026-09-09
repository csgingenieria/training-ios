import Testing
import Foundation

@testable import Dobacksoft_Training

/// Telling a cancellation apart from a real failure.
///
/// Switching convocatoria chips mid-load cancels the previous request, and
/// wrapped as `.transport` the screen said «No se ha podido conectar. Compruebe
/// su conexión a la red» with the network perfectly fine — blaming the
/// candidate for something the app did.
struct CancellationTests {
    /// **Both shapes**, because handling one leaves the defect half fixed.
    @Test func bothShapesOfCancellationAreRecognised() {
        #expect(CancellationError().isCancellation)
        #expect(URLError(.cancelled).isCancellation)
    }

    /// And nothing else is. The control that matters: if this returned true for
    /// a real failure, every network error would be swallowed in silence and
    /// the screen would sit on a spinner for ever.
    @Test func aRealFailureIsNotACancellation() {
        for error in [
            URLError(.notConnectedToInternet),
            URLError(.timedOut),
            URLError(.cannotFindHost),
            URLError(.networkConnectionLost)
        ] {
            #expect(!error.isCancellation, "\(error.code) no es una cancelación")
        }
        #expect(!NSError(domain: "otro", code: 0).isCancellation)
    }

    /// A timeout is the one most likely to be confused with a cancellation —
    /// both end a request early — and it is a real failure the person needs
    /// told about.
    @Test func aTimeoutIsAFailureAndNotACancellation() {
        #expect(!URLError(.timedOut).isCancellation)
    }
}
