import SwiftUI

/// S-9: the order is received. No top bar and no way back to S-8; back and the home button both lead to S-2.
struct ConfirmationView: View {
    private static let markSize: CGFloat = 96

    @State var model: ConfirmationViewModel
    let onHome: () -> Void
    @State private var played = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                statusMark
                Text(SendStrings.confirmationTitle)
                    .textStyle(Typography.screenTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(AccessibilityID.confirmationTitle)
                codeCard
                Text(SendStrings.confirmationMessage)
                    .textStyle(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(AccessibilityID.confirmationMessage)
                contacts
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.xxl)
            .padding(.bottom, Spacing.lg)
        }
        .bottomActionBar {
            ActionButton(title: SendStrings.confirmationHome, emphasis: .secondary, action: onHome)
                .accessibilityIdentifier(AccessibilityID.confirmationHome)
        }
        .toast(toastMessage)
        .appBackground()
        .customBackNavigation()
        .sensoryFeedback(.success, trigger: played)
        .onAppear { played = true }
    }

    private var statusMark: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: Self.markSize))
            .foregroundStyle(Palette.primary)
            .scaleEffect(played ? 1 : 0.6)
            .opacity(played ? 1 : 0)
            .animation(Motion.standardSpring, value: played)
            .accessibilityHidden(true)
    }

    private var codeCard: some View {
        GlassCard {
            VStack(spacing: Spacing.sm) {
                Text(SendStrings.confirmationCodeLabel)
                    .textStyle(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                // Long-press selects and copies the plain code (no extra copy button).
                Text(verbatim: model.code)
                    .textStyle(Typography.heroTitle)
                    .monospaced()
                    .foregroundStyle(Palette.primaryDeep)
                    .textSelection(.enabled)
                    .accessibilityLabel(spokenCode)
                    .accessibilityIdentifier(AccessibilityID.confirmationCode)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The code is read character by character.
    private var spokenCode: Text {
        var text = AttributedString(model.spokenLabel)
        if let range = text.range(of: model.code) { text[range].accessibilitySpeechSpellsOutCharacters = true }
        return Text(text)
    }

    private var contacts: some View {
        GlassGroup {
            AdaptiveStack(spacing: Spacing.contactGap) {
                ActionButton(title: Strings.homeButtonZalo, systemImage: "message", emphasis: .secondary) {
                    Task { await model.openZalo() }
                }
                .accessibilityIdentifier(AccessibilityID.confirmationZalo)
                ActionButton(title: Strings.homeButtonPhone, systemImage: "phone", emphasis: .secondary) {
                    Task { await model.openPhone() }
                }
                .accessibilityIdentifier(AccessibilityID.confirmationPhone)
            }
        }
        .disabled(!model.contactsEnabled)
    }

    private var toastMessage: Binding<LocalizedStringResource?> {
        Binding(
            get: { model.contact.failure?.message },
            set: { if $0 == nil { model.contact.failure = nil } }
        )
    }
}
