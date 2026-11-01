import BanhDesign
import SwiftUI

/// Identifiers of the two buttons and their dialogs: `admin.account.*` in the sheet, `admin.settings.*` on the tab.
struct AccountActionIDs {
    let signOutOthers: String
    let signOutOthersYes: String
    let signOut: String
    let signOutYes: String

    static let account = AccountActionIDs(
        signOutOthers: AdminID.accountSignOutOthers, signOutOthersYes: AdminID.accountSignOutOthersYes,
        signOut: AdminID.accountSignOut, signOutYes: AdminID.accountSignOutYes
    )
    static let settings = AccountActionIDs(
        signOutOthers: AdminID.settingsSignOutOthers, signOutOthersYes: AdminID.settingsSignOutOthersYes,
        signOut: AdminID.settingsSignOut, signOutYes: AdminID.settingsSignOutYes
    )
}

/// "Sign out all other phones" and "Sign out", each with its confirm dialog (S-A6, S-A13).
struct AccountActions: View {
    @Bindable var model: AccountViewModel
    let ids: AccountActionIDs

    var body: some View {
        VStack(spacing: Spacing.md) {
            ActionButton(title: AStrings.signOutOthers, emphasis: .secondary, showsProgress: model.isBusy) {
                model.showsSignOutOthers = true
            }
            .disabled(model.isBusy)
            .accessibilityIdentifier(ids.signOutOthers)
            ActionButton(title: AStrings.signOut, emphasis: .destructive) { model.showsSignOut = true }
                .disabled(model.isBusy)
                .accessibilityIdentifier(ids.signOut)
        }
        .toast($model.toast, identifier: AdminID.toast)
        .sensoryFeedback(.success, trigger: model.successCount)
        .alert(String(localized: AStrings.signOutOthersTitle), isPresented: $model.showsSignOutOthers) {
            Button(String(localized: AStrings.back), role: .cancel) {}
            Button(String(localized: AStrings.signOutOthers)) { Task { await model.signOutOthers() } }
                .accessibilityIdentifier(ids.signOutOthersYes)
        } message: { Text(AStrings.signOutOthersBody) }
        .alert(String(localized: AStrings.signOutTitle), isPresented: $model.showsSignOut) {
            Button(String(localized: AStrings.back), role: .cancel) {}
            Button(String(localized: AStrings.signOut), role: .destructive) { model.signOut() }
                .accessibilityIdentifier(ids.signOutYes)
        } message: { Text(AStrings.signOutBody) }
    }
}
