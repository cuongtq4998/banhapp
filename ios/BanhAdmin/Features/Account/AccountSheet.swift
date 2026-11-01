import BanhDesign
import SwiftUI

/// S-A13 Account (sheet, staff): name, e-mail, role and the two sign-out buttons.
struct AccountSheet: View {
    @Bindable var model: AccountViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(AStrings.accountTitle).textStyle(Typography.heading).foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                GlassCard {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(verbatim: model.user.account.name).textStyle(Typography.bodyStrong)
                            .accessibilityIdentifier(AdminID.accountName)
                        if let email = model.user.email {
                            Text(verbatim: email).textStyle(Typography.body).foregroundStyle(Palette.textSecondary)
                                .accessibilityIdentifier(AdminID.accountEmail)
                        }
                        Text(model.roleText).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                    }
                }
                AccountActions(model: model, ids: .account)
            }
            .padding(Spacing.lg)
        }
        .presentationDetents([.medium, .large])
        .background(Palette.surfaceSolid.ignoresSafeArea())
    }
}

/// Owner's Settings tab: a placeholder in this slice (the five areas come with the settings slices),
/// with the account data and the two sign-out buttons so that the owner can sign out (S-A6).
struct SettingsPlaceholderView: View {
    @Bindable var model: AccountViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(AStrings.settingsTitle).textStyle(Typography.screenTitle).foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                GlassCard {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(verbatim: model.user.account.name).textStyle(Typography.bodyStrong)
                        if let email = model.user.email {
                            Text(verbatim: email).textStyle(Typography.body).foregroundStyle(Palette.textSecondary)
                        }
                        Text(model.roleText).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                    }
                }
                AccountActions(model: model, ids: .settings)
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.sm)
        }
        .appBackground()
    }
}
