import BanhDesign
import SwiftUI

/// S-A12 Staff: count pill, add button, the owner first, then staff by name.
struct StaffView: View {
    @Bindable var model: StaffViewModel
    let onBack: () -> Void

    var body: some View {
        SettingsScaffold(title: String(localized: AStrings.rowStaff), screen: AdminOwnerID.staff, onBack: onBack, showsBar: false) {
            LoadStateView(load: model.load, screen: AdminOwnerID.staff, retry: { Task { await model.retry() } }) { _ in
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(verbatim: AStrings.staffCount(model.activeStaff)).textStyle(Typography.bodyStrong)
                        .padding(.horizontal, Spacing.md).frame(minHeight: 32).background(Palette.chipFill, in: Capsule())
                        .accessibilityIdentifier(AdminOwnerID.staffCount)
                    ActionButton(title: AStrings.addStaff, systemImage: "plus") { model.add() }
                        .disabled(model.isFull)
                        .accessibilityIdentifier(AdminOwnerID.staffAdd)
                    if model.isFull {
                        Text(AStrings.staffFull).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                            .accessibilityIdentifier(AdminOwnerID.staffFull)
                    }
                    ForEach(model.accounts) { account in row(account) }
                    if model.onlyOwner {
                        Text(AStrings.staffNone).textStyle(Typography.body).foregroundStyle(Palette.textSecondary)
                            .accessibilityIdentifier(AdminOwnerID.staffNone)
                    }
                }
            }
        } bar: { EmptyView() }
        .task { await model.reload() }
        .sheet(item: $model.adder) { StaffAddSheet(model: $0) }
        // A second sheet on the same view would replace the first: it hangs on its own background view.
        .background {
            Color.clear.sheet(isPresented: Binding(get: { model.selected != nil }, set: { if !$0 { model.selectedID = nil } })) {
                if let account = model.selected { StaffDetailSheet(model: model, account: account) }
            }
        }
    }

    private func row(_ account: StaffAccount) -> some View {
        Button { model.open(account) } label: {
            GlassCard(padding: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(verbatim: account.name).textStyle(Typography.cardTitle).foregroundStyle(Palette.textPrimary)
                        Text(verbatim: account.email).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                    }
                    Spacer(minLength: Spacing.sm)
                    if account.role == .owner {
                        StatusBadge(tone: .confirmed, text: String(localized: AStrings.roleOwner))
                    } else {
                        StatusBadge(
                            tone: account.isActive ? .confirmed : .completed,
                            text: String(localized: account.isActive ? AStrings.acctActive : AStrings.acctOff)
                        )
                        Image(systemName: "chevron.right").foregroundStyle(Palette.textSecondary).accessibilityHidden(true)
                    }
                }
            }
            .opacity(account.isActive ? 1 : 0.7)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .disabled(account.role == .owner)
        .accessibilityIdentifier(AdminOwnerID.staffRow(account.id))
    }
}

/// Add sheet.
struct StaffAddSheet: View {
    @Bindable var model: StaffAddModel
    @FocusState private var focus: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(AStrings.addStaff).textStyle(Typography.heading).foregroundStyle(Palette.textPrimary).accessibilityAddTraits(.isHeader)
                if let text = model.banner { InlineMessage(kind: .error, text: text).accessibilityIdentifier(AdminOwnerID.staffAddMessage) }
                FormTextField(
                    label: AStrings.fStaffName, text: $model.name, identifier: AdminOwnerID.staffAddName, error: model.errors["name"],
                    errorIdentifier: AdminOwnerID.fieldError("staffAdd", "name"), focus: $focus
                )
                FormTextField(
                    label: AStrings.emailLabel, text: $model.email, identifier: AdminOwnerID.staffAddEmail, error: model.errors["email"],
                    errorIdentifier: AdminOwnerID.fieldError("staffAdd", "email"), keyboard: .emailAddress, autocapitalize: false, focus: $focus
                )
                Text(AStrings.staffAddHelp).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                ActionButton(title: AStrings.addStaffSave, showsProgress: model.isBusy) {
                    focus = nil
                    Task { await model.save() }
                }
                .disabled(!model.canSave)
                .accessibilityIdentifier(AdminOwnerID.staffAddSave)
            }
            .padding(Spacing.lg)
        }
        .onChange(of: model.focusRequest) { _, id in focus = id }
        .presentationDetents([.medium, .large])
        .background(Palette.surfaceSolid.ignoresSafeArea())
    }
}

/// Detail sheet of a staff account: data and one button, switch off (with a dialog) or on.
struct StaffDetailSheet: View {
    @Bindable var model: StaffViewModel
    let account: StaffAccount

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text(verbatim: account.name).textStyle(Typography.heading).foregroundStyle(Palette.textPrimary).accessibilityAddTraits(.isHeader)
            GlassCard {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(verbatim: account.email).textStyle(Typography.body)
                    Text(AStrings.roleStaff).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                    Text(account.isActive ? AStrings.acctActive : AStrings.acctOff).textStyle(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            if let text = model.detailMessage { InlineMessage(kind: .error, text: text).accessibilityIdentifier(AdminOwnerID.staffDetailMessage) }
            if account.isActive {
                ActionButton(title: AStrings.deactivate, emphasis: .destructive, showsProgress: model.isBusy) { model.showsDeactivate = true }
                    .disabled(model.isBusy)
                    .accessibilityIdentifier(AdminOwnerID.staffDeactivate)
            } else {
                ActionButton(title: AStrings.reactivate, showsProgress: model.isBusy) { Task { await model.reactivate() } }
                    .disabled(model.isBusy)
                    .accessibilityIdentifier(AdminOwnerID.staffReactivate)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.lg)
        .presentationDetents([.medium, .large])
        .background(Palette.surfaceSolid.ignoresSafeArea())
        .alert(AStrings.deactivateTitle(name: account.name), isPresented: $model.showsDeactivate) {
            Button(String(localized: AStrings.back), role: .cancel) {}
            Button(String(localized: AStrings.deactivate), role: .destructive) { Task { await model.deactivate() } }
                .accessibilityIdentifier(AdminOwnerID.staffDeactivateYes)
        } message: { Text(verbatim: AStrings.deactivateBody(name: account.name)) }
    }
}
