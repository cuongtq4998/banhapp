import SwiftUI

@main
struct BanhApp: App {
    private let environment = AppEnvironment.make()

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
    }
}
