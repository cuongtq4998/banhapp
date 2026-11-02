import SwiftUI
import UIKit

extension View {
    /// Shows `message` in a capsule at the top for `Motion.toastDuration`, then clears it.
    public func toast(_ message: Binding<String?>, identifier: String) -> some View {
        modifier(ToastModifier(message: message, identifier: identifier))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: String?
    let identifier: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                Text(verbatim: message)
                    .textStyle(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .capsuleGlassSurface()
                    .padding(.horizontal, Spacing.screenMargin)
                    .padding(.top, Spacing.sm)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier(identifier)
                    .onAppear { UIAccessibility.post(notification: .announcement, argument: message) }
                    .task(id: message) {
                        try? await Task.sleep(for: Motion.toastDuration)
                        self.message = nil
                    }
            }
        }
        .animation(.easeInOut(duration: reduceMotion ? Motion.short : Motion.medium), value: message == nil)
    }
}
