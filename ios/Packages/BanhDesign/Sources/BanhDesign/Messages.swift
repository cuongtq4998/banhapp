import SwiftUI
import UIKit

/// A message near a control or at the top of a section (`InlineMessage`). Announced when it appears.
public struct InlineMessage: View {
    public enum Kind { case error, info, warning }

    let kind: Kind
    let text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: symbol).foregroundStyle(tint).accessibilityHidden(true)
            Text(verbatim: text)
                .textStyle(Typography.body)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.inner)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(container, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .combine)
        .onAppear { UIAccessibility.post(notification: .announcement, argument: text) }
    }

    private var symbol: String {
        switch kind {
        case .error: "exclamationmark.circle.fill"
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch kind {
        case .error: Palette.error
        case .info: Palette.primary
        case .warning: Palette.statusNewText
        }
    }

    private var container: Color {
        switch kind {
        case .error: Palette.errorContainer
        case .info: Palette.primaryContainer
        case .warning: Palette.warningContainer
        }
    }
}

/// Full-area error, offline and empty state (`StateView`): icon, text, and one optional action.
public struct StateView: View {
    let symbol: String
    let message: LocalizedStringResource
    var actionTitle: LocalizedStringResource?
    var actionIdentifier: String
    var action: (() -> Void)?

    public init(
        symbol: String = "exclamationmark.triangle", message: LocalizedStringResource,
        actionTitle: LocalizedStringResource? = nil, actionIdentifier: String = "", action: (() -> Void)? = nil
    ) {
        self.symbol = symbol
        self.message = message
        self.actionTitle = actionTitle
        self.actionIdentifier = actionIdentifier
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(Palette.textSecondary).accessibilityHidden(true)
            Text(message)
                .textStyle(Typography.body)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                ActionButton(title: actionTitle, emphasis: .secondary, action: action)
                    .accessibilityIdentifier(actionIdentifier)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

/// Placeholder block shown while data loads.
public struct SkeletonBlock: View {
    public init() {}

    public var body: some View {
        RoundedRectangle(cornerRadius: Radius.cardRow, style: .continuous)
            .fill(Palette.textPrimary.opacity(0.08))
            .accessibilityHidden(true)
    }
}
