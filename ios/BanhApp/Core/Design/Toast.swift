import SwiftUI

extension View {
    /// Shows `message` in a capsule at the top for `Motion.toastDuration`, then clears it.
    func toast(_ message: Binding<LocalizedStringResource?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: LocalizedStringResource?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                Text(message)
                    .textStyle(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .capsuleGlassSurface()
                    .padding(.horizontal, Spacing.screenMargin)
                    .padding(.top, Spacing.sm)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier(AccessibilityID.toast)
                    // The text appears without focus moving, so VoiceOver must be told.
                    .onAppear { UIAccessibility.post(notification: .announcement, argument: String(localized: message)) }
                    .task(id: String(localized: message)) {
                        try? await Task.sleep(for: Motion.toastDuration)
                        self.message = nil
                    }
            }
        }
        .animation(.easeInOut(duration: reduceMotion ? Motion.short : Motion.medium), value: message == nil)
    }
}
