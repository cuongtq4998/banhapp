import BanhDesign
import SwiftUI

/// S-A2 Sign in: code.
struct CodeView: View {
    @Bindable var model: CodeViewModel
    let onChangeEmail: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                BackButton(label: AStrings.back, identifier: AdminID.navBack, action: onChangeEmail)
                Text(AStrings.codeTitle).textStyle(Typography.display).foregroundStyle(Palette.textPrimary)
                Text(verbatim: AStrings.codePrompt(email: model.email))
                    .textStyle(Typography.body).foregroundStyle(Palette.textSecondary)
                OtpField(
                    code: $model.code, label: AStrings.codeFieldA11y, identifier: AdminID.codeField,
                    isError: model.message != nil, shakeTrigger: model.shakeCount
                )
                .frame(maxWidth: .infinity)
                if let message = model.message { FieldError(text: message.text, identifier: AdminID.codeError) }
                resendRow
                ActionButton(title: AStrings.signIn, showsProgress: model.isSubmitting) {
                    Task { await model.submit() }
                }
                .disabled(!model.canSubmit)
                .accessibilityIdentifier(AdminID.codeSubmit)
                TextLinkButton(AStrings.changeEmail, action: onChangeEmail)
                    .accessibilityIdentifier(AdminID.codeChangeEmail)
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.sm)
        }
        .scrollDismissesKeyboard(.never)
        .appBackground()
        .task { model.startCountdown() }
        .onDisappear { model.stopCountdown() }
    }

    @ViewBuilder
    private var resendRow: some View {
        if model.resendRemaining > 0 {
            Text(verbatim: AStrings.resendWait(seconds: model.resendRemaining))
                .textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                .accessibilityIdentifier(AdminID.codeResend)
        } else {
            TextLinkButton(AStrings.resend) { Task { await model.resend() } }
                .accessibilityIdentifier(AdminID.codeResend)
        }
    }
}
