import Testing
import Foundation

@testable import Dobacksoft_Training

/// What the widget's tap resolves to.
///
/// The widget told the candidate to open «Mi posición» and tapping it opened
/// Convocatorias, because there was no URL scheme, no `widgetURL` and no
/// `onOpenURL` anywhere in the project. The instruction was true and the tap
/// contradicted it.
struct DeepLinkTests {
    private func link(_ string: String) -> DeepLink? {
        guard let url = URL(string: string) else {
            Issue.record("«\(string)» no es una URL, así que este caso no prueba nada")
            return nil
        }
        return DeepLink(url: url)
    }

    // MARK: - Lo que sí es un enlace nuestro

    @Test func theWidgetsLinkResolvesToMyPosition() {
        #expect(link("dobacksoft-training://mi-posicion") == .miPosicion)
    }

    /// URL schemes are case-insensitive by RFC 3986, and iOS will hand us
    /// whatever the caller typed. Rejecting a differently-cased scheme would
    /// drop a link that is ours.
    @Test func theSchemeIsCaseInsensitive() {
        #expect(link("Dobacksoft-Training://mi-posicion") == .miPosicion)
        #expect(link("DOBACKSOFT-TRAINING://mi-posicion") == .miPosicion)
    }

    /// A trailing slash is the same link. `widgetURL` round-trips through the
    /// system and the shape is not ours to guarantee.
    @Test func aTrailingSlashIsTheSameLink() {
        #expect(link("dobacksoft-training://mi-posicion/") == .miPosicion)
    }

    // MARK: - Lo que no

    /// Another scheme is not ours, however familiar the host looks. This is
    /// the load-bearing rejection: a web URL must never be able to drive
    /// navigation inside the app.
    @Test func anotherSchemeIsNeverOurs() {
        #expect(link("https://mi-posicion") == nil)
        #expect(link("https://training.cmadrid.example/mi-posicion") == nil)
        #expect(link("otra-app://mi-posicion") == nil)
    }

    /// An unknown destination is not a destination. Falling back to some
    /// default screen would make a typo look like a working link, and a future
    /// link from a newer widget would land somewhere arbitrary instead of
    /// being ignored.
    @Test func anUnknownDestinationIsIgnored() {
        #expect(link("dobacksoft-training://ranking") == nil)
        #expect(link("dobacksoft-training://") == nil)
        #expect(link("dobacksoft-training://mi-posicion-extra") == nil)
    }

    /// The destination is matched on the host, not searched for inside the
    /// string. Otherwise anything containing the word would resolve.
    @Test func theDestinationIsNotMerelyContained() {
        #expect(link("dobacksoft-training://ranking?volver=mi-posicion") == nil)
    }

    // MARK: - La frontera entre el widget y la app

    /// **The URL the widget actually writes is the URL the app parses.**
    ///
    /// This is the one test neither target could write alone, and the reason
    /// the string lives in `SharedSnapshot` instead of being typed twice. With
    /// two copies, the widget would keep opening a URL the app had stopped
    /// recognising — the tap would do nothing, silently, and every unit test
    /// on either side would still pass.
    @Test func theURLTheWidgetWritesIsTheOneTheAppParses() throws {
        let written = try #require(SnapshotLink.miPosicion, "el widget no tiene URL que poner")
        #expect(DeepLink(url: written) == .miPosicion)
    }

    /// And the round trip closes in both directions.
    @Test func theLinkRebuildsTheSameURL() throws {
        let rebuilt = try #require(DeepLink.miPosicion.url)
        #expect(DeepLink(url: rebuilt) == .miPosicion)
        #expect(rebuilt == SnapshotLink.miPosicion)
    }

    /// The scheme is declared to the system, or nothing arrives at all.
    /// `onOpenURL` never fires for a scheme missing from `CFBundleURLTypes`,
    /// and the whole chain would fail with every test above still green.
    @Test func theSchemeIsDeclaredInTheBundle() throws {
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        let declared = (types ?? [])
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .flatMap { $0 }
            .map { $0.lowercased() }

        #expect(declared.contains(DeepLink.scheme),
                "«\(DeepLink.scheme)» no está en CFBundleURLTypes: el sistema no entregaría nada")
    }

    // MARK: - A qué sección lleva

    /// And it maps onto the router's own section, so there is one list of
    /// destinations and not two.
    @Test func theLinkNamesASectionTheRouterKnows() {
        #expect(DeepLink.miPosicion.section == .miPosicion)
    }

    // MARK: - El buzón: sobrevive al arranque en frío

    /// A cold launch from the widget delivers the URL while the launch screen
    /// is still up and the dashboard does not exist yet. Without somewhere to
    /// hold it, the link is silently lost — which is the same defect as having
    /// no link at all, only harder to notice.
    @MainActor
    @Test func aLinkArrivingBeforeTheDashboardExistsIsHeld() {
        let inbox = DeepLinkInbox()
        inbox.receive(URL(string: "dobacksoft-training://mi-posicion")!)
        #expect(inbox.pending == .miPosicion)
    }

    /// Consumed exactly once. A link that stayed pending would drag the
    /// candidate back to «Mi posición» every time the dashboard rebuilt — on
    /// every rotation, on every Split View drag.
    @MainActor
    @Test func theLinkIsConsumedExactlyOnce() {
        let inbox = DeepLinkInbox()
        inbox.receive(URL(string: "dobacksoft-training://mi-posicion")!)

        #expect(inbox.consume() == .miPosicion)
        #expect(inbox.consume() == nil)
        #expect(inbox.pending == nil)
    }

    /// A URL that is not ours does not clear a link already waiting, and does
    /// not become one.
    @MainActor
    @Test func aForeignURLNeitherArrivesNorEvicts() {
        let inbox = DeepLinkInbox()
        inbox.receive(URL(string: "dobacksoft-training://mi-posicion")!)
        inbox.receive(URL(string: "https://example.com")!)

        #expect(inbox.pending == .miPosicion)
    }

    // MARK: - El atajo de Siri

    /// **One map of destinations, not two.** The intent takes its route from
    /// `DeepLink`, so Siri and the widget cannot drift to different screens.
    @Test func theSiriShortcutUsesTheSameDestinationMap() {
        #expect(OpenStandingIntent.route == .miPosicion)
        #expect(OpenStandingIntent.route.section == .miPosicion)
    }

    /// It opens the app rather than answering out loud. A spoken answer would
    /// say someone's position in a room where others can hear it, and the
    /// screen needs the session anyway.
    @Test func theShortcutOpensTheAppInsteadOfAnswering() {
        #expect(OpenStandingIntent.openAppWhenRun)
    }

    /// **One inbox, shared.** An `AppIntent` runs outside the view hierarchy
    /// and has no access to the SwiftUI environment, so it needs a mailbox it
    /// can reach — and `RootView` must read that same one. Two inboxes would
    /// mean the widget's link and Siri's lose each other.
    @MainActor
    @Test func theIntentAndTheAppShareOneInbox() {
        let inbox = DeepLinkInbox.shared
        _ = inbox.consume()

        inbox.receive(DeepLink.miPosicion)
        #expect(inbox.pending == .miPosicion)
        #expect(inbox.consume() == .miPosicion)
        #expect(inbox.pending == nil, "se atiende una vez, como el del widget")
    }
}
