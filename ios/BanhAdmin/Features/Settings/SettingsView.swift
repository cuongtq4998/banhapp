import BanhDesign
import SwiftUI

/// S-A6 Settings (owner): five rows, the note, the two sign-out buttons.
struct SettingsView: View {
    @Bindable var coordinator: SettingsCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(AStrings.settingsTitle).textStyle(Typography.screenTitle).foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                GlassCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        row(AStrings.rowCakes, coordinator.overview.cakesValue, .cakes, AdminOwnerID.rowCakes)
                        Divider()
                        row(AStrings.rowRules, coordinator.overview.rulesValue, .rules, AdminOwnerID.rowRules)
                        Divider()
                        row(AStrings.rowDeliverySet, coordinator.overview.deliveryValue, .delivery, AdminOwnerID.rowDelivery)
                        Divider()
                        row(AStrings.rowShop, coordinator.overview.shopValue, .shop, AdminOwnerID.rowShop)
                        Divider()
                        row(AStrings.rowStaff, coordinator.overview.staffValue, .staff, AdminOwnerID.rowStaff)
                    }
                }
                Text(AStrings.newOrdersOnly).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                accountCard
                AccountActions(model: coordinator.account, ids: .settings)
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.sm)
        }
        .refreshable { await coordinator.overview.load() }
        .appBackground()
        .task { await coordinator.overview.load() }
        .accessibilityIdentifier(AdminOwnerID.settingsRoot)
    }

    private func row(_ title: LocalizedStringResource, _ value: String, _ route: SettingsCoordinator.Route, _ id: String) -> some View {
        Button { coordinator.path.append(route) } label: {
            HStack(spacing: Spacing.md) {
                Text(title).textStyle(Typography.bodyStrong).foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(verbatim: value).textStyle(Typography.body).foregroundStyle(Palette.textSecondary)
                    .accessibilityIdentifier(AdminOwnerID.rowValue(id))
                Image(systemName: "chevron.right").foregroundStyle(Palette.textSecondary).accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    /// Who is signed in: name, e-mail and role, no action (spec v1.3).
    private var accountCard: some View {
        GlassCard(padding: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(verbatim: coordinator.account.user.account.name).textStyle(Typography.bodyStrong)
                    .accessibilityIdentifier(AdminID.accountName)
                if let email = coordinator.account.user.email {
                    Text(verbatim: email).textStyle(Typography.body).foregroundStyle(Palette.textSecondary)
                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(AdminID.accountEmail)
                }
                Text(coordinator.account.roleText).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
