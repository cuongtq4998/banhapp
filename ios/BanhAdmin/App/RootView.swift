import BanhDesign
import SwiftUI

/// Chooses the screen from the coordinator's state and pins the light palette of the design board.
struct RootView: View {
    @State var coordinator: AppCoordinator
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            switch coordinator.screen {
            case .launching: LaunchView(failed: false, retry: {})
            case .launchFailed: LaunchView(failed: true, retry: coordinator.retryLaunch)
            case .signIn: signIn
            case .signedIn(let orders): ShellView(coordinator: orders)
            }
            // The task switcher snapshot must not show customer data (BR-7, AC-45).
            if scenePhase != .active { PrivacyCover() }
        }
        .preferredColorScheme(.light)
        .task { await coordinator.start() }
    }

    @ViewBuilder
    private var signIn: some View {
        switch coordinator.step! {
        case .email(let model): EmailView(model: model, banner: coordinator.banner)
        case .code(let model): CodeView(model: model, onChangeEmail: coordinator.changeEmail)
        }
    }
}

/// Brand view shown at start and, with the two ids of retry, when the first request fails offline.
struct LaunchView: View {
    let failed: Bool
    let retry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            LogoMark(label: AStrings.signInTitle)
            if failed {
                StateView(message: AStrings.offline, actionTitle: AStrings.retry, actionIdentifier: AdminID.ordersRetry, action: retry)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }
}

/// Opaque cover while the app is inactive or in the background.
struct PrivacyCover: View {
    var body: some View {
        Palette.surfaceSolid.ignoresSafeArea().overlay { LogoMark(label: AStrings.signInTitle) }
    }
}
