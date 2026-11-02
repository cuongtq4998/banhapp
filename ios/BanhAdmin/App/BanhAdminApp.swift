import SwiftUI

@main
struct BanhAdminApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let environment = AdminEnvironment.make()

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: AppCoordinator(environment: environment))
        }
    }
}
