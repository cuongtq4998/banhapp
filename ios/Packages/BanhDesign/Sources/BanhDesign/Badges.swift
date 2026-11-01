import SwiftUI

/// Order status next to the code. The word is always shown, never colour alone.
public struct StatusBadge: View {
    public enum Tone { case new, confirmed, completed, cancelled }

    let tone: Tone
    let text: String

    public init(tone: Tone, text: String) {
        self.tone = tone
        self.text = text
    }

    public var body: some View {
        Text(verbatim: text)
            .textStyle(Typography.badge)
            .foregroundStyle(colors.text)
            .padding(.horizontal, 10)
            .frame(minHeight: Size.badgeHeight)
            .background(colors.fill, in: Capsule())
    }

    private var colors: (fill: Color, text: Color) {
        switch tone {
        case .new: (Palette.statusNewFill, Palette.statusNewText)
        case .confirmed: (Palette.statusConfirmedFill, Palette.statusConfirmedText)
        case .completed: (Palette.statusCompletedFill, Palette.statusCompletedText)
        case .cancelled: (Palette.statusCancelledFill, Palette.statusCancelledText)
        }
    }
}

/// Red "due today" or "overdue N days" mark: text and a clock icon, never colour alone.
public struct DueMark: View {
    let text: String

    public init(text: String) { self.text = text }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "clock").accessibilityHidden(true)
            Text(verbatim: text)
        }
        .textStyle(Typography.badge)
        .foregroundStyle(Palette.dueText)
        .padding(.horizontal, 10)
        .frame(minHeight: Size.badgeHeight)
        .background(Palette.dueFill, in: Capsule())
    }
}

/// Red round number (the staff header count). Hidden at 0, "99+" above 99.
public struct CountBadge: View {
    let count: Int

    public init(count: Int) { self.count = count }

    public static func label(for count: Int) -> String { count > 99 ? "99+" : String(count) }

    public var body: some View {
        Text(verbatim: Self.label(for: count))
            .textStyle(Typography.badge)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(minWidth: Size.badgeHeight, minHeight: Size.badgeHeight)
            .background(Palette.error, in: Capsule())
    }
}

/// Status or date filter chip, single choice. 44 pt high.
public struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var showsChevron: Bool

    public init(title: String, isSelected: Bool, showsChevron: Bool = false) {
        self.title = title
        self.isSelected = isSelected
        self.showsChevron = showsChevron
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(verbatim: title)
            if showsChevron { Image(systemName: "chevron.down").font(.caption2).accessibilityHidden(true) }
        }
        .textStyle(Typography.smallButton)
        .foregroundStyle(isSelected ? Palette.onPrimary : Palette.textPrimary)
        .padding(.horizontal, Spacing.lg)
        .frame(minHeight: Size.touchTarget)
        .background(isSelected ? Palette.primary : Palette.chipFill, in: Capsule())
        .animation(.easeInOut(duration: Motion.short), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
