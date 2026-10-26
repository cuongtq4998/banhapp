import SwiftUI
import UIKit

/// The round glass back button of S-3 and S-4. The navigation bar is hidden on those screens, so this
/// button replaces the system one.
struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: Size.chevronBack, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: Size.backButton, height: Size.backButton)
                .circleGlassSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Strings.commonBack))
        .accessibilityIdentifier(AccessibilityID.backButton)
    }
}

extension View {
    /// Hides the system navigation bar but keeps the swipe-from-the-edge back gesture, which UIKit turns
    /// off together with the bar. SwiftUI has no setting for this, so the navigation controller's
    /// gesture delegate is cleared.
    func customBackNavigation() -> some View {
        toolbar(.hidden, for: .navigationBar)
            .background(SwipeBackEnabler())
    }
}

private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}
