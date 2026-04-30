import SwiftUI

@main
struct Dobacksoft_TrainingApp: App {
    @State private var auth = AuthSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
        }
    }
}
