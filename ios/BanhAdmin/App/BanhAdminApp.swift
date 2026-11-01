import SwiftUI

@main
struct BanhAdminApp: App {
    private let environment = AdminEnvironment.make()

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: AppCoordinator(environment: environment))
        }
    }
}
