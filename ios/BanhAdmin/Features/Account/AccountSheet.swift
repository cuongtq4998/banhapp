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
                        // The e-mail comes from GET /v1/admin/me or from the sign-in form: always shown.
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
