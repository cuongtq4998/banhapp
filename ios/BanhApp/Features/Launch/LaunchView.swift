import SwiftUI

/// S-1: the logo only. No text, no button, no spinner; start work happens behind it.
struct LaunchView: View {
    private static let startScale: CGFloat = 0.9

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        LogoMark(scale: .large)
            .accessibilityIdentifier(AccessibilityID.launchLogo)
            .scaleEffect(appeared || reduceMotion ? 1 : Self.startScale)
            .opacity(appeared ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appBackground()
            .onAppear {
                withAnimation(.easeOut(duration: reduceMotion ? Motion.short : Motion.long)) { appeared = true }
            }
    }
}
