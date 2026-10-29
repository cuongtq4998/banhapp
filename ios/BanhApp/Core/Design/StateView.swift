import SwiftUI

/// Full-area loading and error states (`StateView`). The empty state of slice 1 is the error state:
/// an empty product list is a failed load (api.md 4.1).
struct ErrorStateView: View {
    private static let symbolName = "exclamationmark.triangle"

    let message: LocalizedStringResource
    /// `state.error` for a failed load; the zero-cake state of S-5 passes `state.empty`.
    var identifier = AccessibilityID.errorState
    let retry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: Self.symbolName)
                .font(.largeTitle)
                .foregroundStyle(Palette.error)
                .accessibilityHidden(true)
            Text(message)
                .textStyle(Typography.body)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            ActionButton(title: Strings.commonRetry, emphasis: .secondary, action: retry)
                .accessibilityIdentifier(AccessibilityID.errorRetry)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

/// Placeholder block shown while data loads; announced once as "loading" by its container.
struct SkeletonBlock: View {
    var cornerRadius: CGFloat = Radius.field

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Palette.textPrimary.opacity(0.08))
            .accessibilityHidden(true)
    }
}

extension View {
    /// Marks a group of skeleton blocks as one "loading" element for VoiceOver.
    func loadingAnnouncement(identifier: String) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Strings.commonLoading))
            .accessibilityIdentifier(identifier)
    }
}
