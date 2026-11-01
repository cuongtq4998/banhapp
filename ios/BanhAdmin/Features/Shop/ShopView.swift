import BanhCore
import BanhDesign
import SwiftUI

/// S-A11 Shop info.
struct ShopView: View {
    @Bindable var model: ShopViewModel
    let onBack: () -> Void
    @FocusState private var focus: String?

    var body: some View {
        SettingsScaffold(title: String(localized: AStrings.rowShop), screen: AdminOwnerID.shop, onBack: back, showsBar: model.load.value != nil) {
            LoadStateView(load: model.load, screen: AdminOwnerID.shop, retry: { Task { await model.retryLoad() } }) { _ in form }
        } bar: {
            ActionButton(title: AStrings.save, showsProgress: model.isBusy) {
                focus = nil
                Task { await model.save() }
            }
            .disabled(!model.canSave)
            .accessibilityIdentifier(AdminOwnerID.shopSave)
        }
        .task { await model.loadShop() }
        .onChange(of: model.focusRequest) { _, id in focus = id }
        .discardDialog(isPresented: $model.showsDiscard, discard: onBack)
    }

    private func back() {
        if model.isDirty { model.showsDiscard = true } else { onBack() }
    }

    private func error(_ field: String) -> String? { model.errors[field] }
    private func errorID(_ field: String) -> String { AdminOwnerID.fieldError(AdminOwnerID.shop, field) }

    private var form: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if let text = model.banner {
                InlineMessage(kind: .error, text: text).accessibilityIdentifier(AdminOwnerID.saveError)
            }
            GlassCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    FormTextField(
                        label: AStrings.fShopName, text: $model.name, identifier: AdminOwnerID.shopName, error: error("name"),
                        errorIdentifier: errorID("name"), focus: $focus
                    )
                    FormTextField(
                        label: AStrings.fGreeting, text: $model.greeting, identifier: AdminOwnerID.shopGreeting, error: error("greeting"),
                        errorIdentifier: errorID("greeting"), multiline: true, limit: 300, focus: $focus
                    )
                    FormTextField(
                        label: AStrings.fPhone, text: $model.phone, identifier: AdminOwnerID.shopPhone, error: error("phone_contact"),
                        errorIdentifier: errorID("phone_contact"), keyboard: .phonePad, focus: $focus
                    )
                    FormTextField(
                        label: AStrings.fZalo, text: $model.zalo, identifier: AdminOwnerID.shopZalo, error: error("zalo_contact"),
                        errorIdentifier: errorID("zalo_contact"), keyboard: .asciiCapable, autocapitalize: false, focus: $focus
                    )
                }
            }
        }
    }
}
