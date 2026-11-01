import BanhDesign
import SwiftUI

extension View {
    /// The in-app toast for a new order while the app is open: shown 4 s, a tap opens S-A4 (A_NOTIF_FOREGROUND).
    func foregroundToast(code: Binding<String?>, onOpen: @escaping (String) -> Void) -> some View {
        overlay(alignment: .top) {
            if let value = code.wrappedValue {
                Button { onOpen(value) } label: {
                    Text(verbatim: AStrings.notifForeground(code: value)).textStyle(Typography.bodyStrong)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.md)
                        .capsuleGlassSurface()
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityIdentifier(AdminOwnerID.notifForeground)
                .sensoryFeedback(.selection, trigger: value)
                .task(id: value) {
                    try? await Task.sleep(for: Motion.toastDuration)
                    code.wrappedValue = nil
                }
            }
        }
        .animation(.easeInOut(duration: Motion.medium), value: code.wrappedValue)
    }
}
