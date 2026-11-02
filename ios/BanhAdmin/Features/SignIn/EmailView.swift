import BanhDesign
import SwiftUI

/// S-A1 Sign in: e-mail.
struct EmailView: View {
    @Bindable var model: EmailViewModel
    /// `A_SESSION_ENDED` or `A_OFFLINE_SIGNOUT` when the person arrives here because of that.
    let banner: LocalizedStringResource?
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                LogoMark(label: AStrings.signInTitle)
                Text(AStrings.signInTitle).textStyle(Typography.display).foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                Text(AStrings.signInHint).textStyle(Typography.body).foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                if let banner {
                    InlineMessage(kind: .info, text: String(localized: banner)).accessibilityIdentifier(AdminID.signInBanner)
                }
                field
                if let message = model.visibleMessage { FieldError(text: message.text, identifier: AdminID.signInError) }
                ActionButton(title: AStrings.sendCode, showsProgress: model.isSending) { send() }
                    .disabled(!model.canSend)
                    .accessibilityIdentifier(AdminID.signInSend)
                Text(AStrings.sessionNote).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .appBackground()
    }

    private var field: some View {
        TextField("", text: $model.email)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.send)
            .focused($focused)
            .disabled(model.isSending)
            .onSubmit { send() }
            .accessibilityIdentifier(AdminID.signInEmail)
            .labeledField(AStrings.emailLabel)
    }

    private func send() {
        focused = false
        Task { await model.send() }
    }
}
