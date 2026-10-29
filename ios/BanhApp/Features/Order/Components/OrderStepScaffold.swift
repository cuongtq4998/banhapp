import SwiftUI

/// The frame shared by S-5 to S-8: back button and step indicator on top, the step title, scrolling
/// content, and the bottom bar with the step's main action (UI document 5.5 to 5.8 Layout).
struct OrderStepScaffold<Content: View, Bar: View>: View {
    let step: OrderStep
    let title: LocalizedStringResource
    @ViewBuilder let content: Content
    @ViewBuilder let bar: Bar

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    BackButton()
                    StepIndicator(current: step.number, count: OrderStep.count)
                }
                .padding(.top, Spacing.backButtonTop)
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
        .scrollDismissesKeyboard(.interactively)
        .bottomActionBar { bar }
        .appBackground()
        .customBackNavigation()
    }
}
