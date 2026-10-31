import SwiftUI

/// The frame shared by S-5 to S-8: back button and step indicator on top, the step title, scrolling
/// content, and the bottom bar with the step's main action (UI document 5.5 to 5.8 Layout).
struct OrderStepScaffold<Content: View, Bar: View>: View {
    let step: OrderStep
    let title: LocalizedStringResource
    /// False while the order is being sent: back must not leave the screen then.
    var backEnabled = true
    /// Changes when the screen wants its top shown again (a new message at the top).
    var scrollToTop = 0
    @ViewBuilder let content: Content
    @ViewBuilder let bar: Bar

    private static var topID: String { "top" }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    BackButton().disabled(!backEnabled)
                    StepIndicator(current: step.number, count: OrderStep.count)
                }
                .padding(.top, Spacing.backButtonTop)
                .id(Self.topID)
                Text(title)
                    .textStyle(Typography.screenTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(AccessibilityID.orderTitle)
                content.padding(.top, Spacing.xs)
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.bottom, Spacing.lg)
        }
        .onChange(of: scrollToTop) { _, _ in withAnimation { proxy.scrollTo(Self.topID, anchor: .top) } }
        }
        .scrollDismissesKeyboard(.interactively)
        .bottomActionBar { bar }
        .appBackground()
        .customBackNavigation()
    }
}
