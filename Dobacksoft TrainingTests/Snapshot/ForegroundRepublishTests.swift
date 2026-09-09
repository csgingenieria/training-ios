import Testing
import Foundation

@testable import Dobacksoft_Training

/// Whether the widget's figures get refreshed when the app comes forward.
///
/// Only «Mi posición» republished real figures, so the snapshot aged even if
/// the candidate opened the app ten times. The widget ages honestly by design,
/// so this is convenience — but the convenience is what stops a two-day-old
/// figure sitting on a home screen for no reason.
@MainActor
struct ForegroundRepublishTests {
    private func publisher(enabled: Bool, convocatoria: String?) -> SnapshotPublisher {
        let defaults = UserDefaults(suiteName: "republish-\(UUID().uuidString)")!
        let publisher = SnapshotPublisher(store: SnapshotStore(directory: nil), defaults: defaults)
        publisher.setQuickViewEnabled(enabled) { .sinDatosAun }
        publisher.lastStandingConvocatoriaId = convocatoria
        return publisher
    }

    /// **With the quick view off there is no request.**
    ///
    /// Asking for someone's position in order not to publish it is a request
    /// that serves nobody and touches data they said they did not want on
    /// their home screen. GDPR art. 25.2 is the reason the toggle exists.
    @Test func withTheQuickViewOffNothingIsFetched() {
        #expect(publisher(enabled: false, convocatoria: "c1").shouldRefreshOnForeground() == false)
    }

    /// And with it on, plus a convocatoria to ask about, it refreshes.
    @Test func withTheQuickViewOnItRefreshes() {
        #expect(publisher(enabled: true, convocatoria: "c1").shouldRefreshOnForeground())
    }

    /// Without a remembered convocatoria there is nothing to ask FOR. It is the
    /// state of a candidate who has never opened «Mi posición».
    @Test func withoutARememberedConvocatoriaThereIsNothingToAsk() {
        #expect(publisher(enabled: true, convocatoria: nil).shouldRefreshOnForeground() == false)
    }

    /// The remembered id survives being read back — it is the whole mechanism.
    @Test func theRememberedConvocatoriaIsReadBack() {
        let publisher = publisher(enabled: true, convocatoria: "conv-42")
        #expect(publisher.lastStandingConvocatoriaId == "conv-42")
    }

    /// **La convocatoria recordada se borra al cerrar sesión.**
    ///
    /// Sin esto, el republicado al volver al frente pediría la posición de la
    /// convocatoria de la persona ANTERIOR con el token de la nueva. En un
    /// dispositivo compartido —el iPad de un instructor pasa de mano en mano—
    /// eso es enseñarle a alguien el puesto de otro en su pantalla de inicio.
    @Test func signingOutForgetsTheConvocatoria() {
        let publisher = publisher(enabled: true, convocatoria: "conv-42")
        publisher.lastStandingConvocatoriaName = "Oposición 2026"

        publisher.clearLastStanding()

        #expect(publisher.lastStandingConvocatoriaId == nil)
        #expect(publisher.lastStandingConvocatoriaName == nil)
        #expect(publisher.shouldRefreshOnForeground() == false, "sin convocatoria no hay nada que pedir")
    }
}
