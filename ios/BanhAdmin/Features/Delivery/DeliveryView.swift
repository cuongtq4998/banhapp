import BanhCore
import BanhDesign
import SwiftUI

/// S-A10 Delivery: districts and time slots, each with an add button, rows and an Active switch.
struct DeliveryView: View {
    @Bindable var model: DeliveryViewModel
    let onBack: () -> Void

    var body: some View {
        SettingsScaffold(title: String(localized: AStrings.rowDeliverySet), screen: AdminOwnerID.delivery, onBack: onBack, showsBar: false) {
            LoadStateView(load: model.load, screen: AdminOwnerID.delivery, retry: { Task { await model.retry() } }) { _ in
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    section(AStrings.secDistricts, add: AStrings.addDistrict, addID: AdminOwnerID.districtAdd, action: model.addDistrict) {
                        if model.districts.isEmpty { Text(AStrings.districtsEmpty).textStyle(Typography.body) }
                        ForEach(model.districts) { district in districtRow(district) }
                    }
                    section(AStrings.secSlots, add: AStrings.addSlot, addID: AdminOwnerID.slotAdd, action: model.addSlot) {
                        if model.slots.isEmpty { Text(AStrings.slotsEmpty).textStyle(Typography.body) }
                        ForEach(model.slots) { slot in slotRow(slot) }
                    }
                }
            }
        } bar: { EmptyView() }
        .task { await model.reload() }
        .sheet(item: $model.districtEditor) { DistrictSheet(model: $0) }
        // A second sheet on the same view would replace the first: it hangs on its own background view.
        .background { Color.clear.sheet(item: $model.slotEditor) { SlotSheet(model: $0) } }
    }

    private func section<Rows: View>(
        _ title: LocalizedStringResource, add: LocalizedStringResource, addID: String, action: @escaping () -> Void,
        @ViewBuilder rows: () -> Rows
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(title).textStyle(Typography.cardTitle).foregroundStyle(Palette.textPrimary).accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: action) {
                    Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                        .frame(width: Size.touchTarget, height: Size.touchTarget).circleGlassSurface()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(add))
                .accessibilityIdentifier(addID)
            }
            rows()
        }
    }

    private func districtRow(_ district: OwnerDistrict) -> some View {
        GlassCard(padding: Spacing.md) {
            HStack(spacing: Spacing.md) {
                Button { model.edit(district) } label: {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(verbatim: district.name).textStyle(Typography.cardTitle).foregroundStyle(Palette.textPrimary)
                        Text(verbatim: MoneyFormatter.format(district.deliveryFeeVnd)).textStyle(Typography.bodyStrong)
                            .foregroundStyle(Palette.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AdminOwnerID.districtRow(district.id))
                activeSwitch(district.isActive, id: district.id, toggleID: AdminOwnerID.districtToggle(district.id)) { on in
                    Task { await model.setDistrict(district, active: on) }
                }
            }
        }
    }

    private func slotRow(_ slot: OwnerSlot) -> some View {
        GlassCard(padding: Spacing.md) {
            HStack(spacing: Spacing.md) {
                Button { model.edit(slot) } label: {
                    Text(verbatim: "\(slot.start) – \(slot.end)").textStyle(Typography.cardTitle).foregroundStyle(Palette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: Size.touchTarget).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AdminOwnerID.slotRow(slot.id))
                activeSwitch(slot.isActive, id: slot.id, toggleID: AdminOwnerID.slotToggle(slot.id)) { on in
                    Task { await model.setSlot(slot, active: on) }
                }
            }
        }
    }

    private func activeSwitch(_ isOn: Bool, id: String, toggleID: String, set: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { isOn }, set: set)) { Text(AStrings.active).textStyle(Typography.caption) }
            .toggleStyle(.switch).tint(Palette.primary)
            .fixedSize()
            .opacity(model.pending.contains(id) ? 0.5 : 1)
            .disabled(model.isBusy)
            .sensoryFeedback(.selection, trigger: isOn)
            .accessibilityIdentifier(toggleID)
    }
}

/// District add and change sheet.
struct DistrictSheet: View {
    @Bindable var model: DistrictEditorModel
    @FocusState private var focus: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(verbatim: model.existing?.name ?? String(localized: AStrings.addDistrict)).textStyle(Typography.heading)
                    .foregroundStyle(Palette.textPrimary).accessibilityAddTraits(.isHeader)
                if let text = model.banner { InlineMessage(kind: .error, text: text).accessibilityIdentifier(AdminOwnerID.districtError) }
                FormTextField(
                    label: AStrings.fDistrict, text: $model.name, identifier: AdminOwnerID.districtName, error: model.errors["name"],
                    errorIdentifier: AdminOwnerID.districtErrorName, focus: $focus
                )
                NumberField(
                    label: AStrings.fFee, text: $model.fee, identifier: AdminOwnerID.districtFee, error: model.errors["delivery_fee_vnd"],
                    errorIdentifier: AdminOwnerID.districtErrorFee, suffix: "đ", focus: $focus
                )
                Text(AStrings.feeEffect).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                ActionButton(title: AStrings.save, showsProgress: model.isBusy) {
                    focus = nil
                    Task { await model.save() }
                }
                .disabled(!model.canSave)
                .accessibilityIdentifier(AdminOwnerID.districtSave)
            }
            .padding(Spacing.lg)
        }
        .onChange(of: model.focusRequest) { _, id in focus = id }
        .presentationDetents([.medium, .large])
        .background(Palette.surfaceSolid.ignoresSafeArea())
    }
}

/// Slot add and change sheet: two 24 hour time pickers.
struct SlotSheet: View {
    @Bindable var model: SlotEditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text(model.existing == nil ? AStrings.slotAddTitle : AStrings.slotEditTitle).textStyle(Typography.heading)
                .foregroundStyle(Palette.textPrimary).accessibilityAddTraits(.isHeader)
            picker(AStrings.fStart, minutes: $model.start, id: AdminOwnerID.slotStart)
            picker(AStrings.fEnd, minutes: $model.end, id: AdminOwnerID.slotEnd)
            if let text = model.error { InlineMessage(kind: .error, text: text).accessibilityIdentifier(AdminOwnerID.slotError) }
            ActionButton(title: AStrings.save, showsProgress: model.isBusy) { Task { await model.save() } }
                .disabled(!model.canSave)
                .accessibilityIdentifier(AdminOwnerID.slotSave)
            Spacer(minLength: 0)
        }
        .padding(Spacing.lg)
        .presentationDetents([.medium, .large])
        .background(Palette.surfaceSolid.ignoresSafeArea())
    }

    private func picker(_ label: LocalizedStringResource, minutes: Binding<Int>, id: String) -> some View {
        let date = Binding<Date>(
            get: { Date(timeIntervalSince1970: TimeInterval(minutes.wrappedValue * 60)) },
            set: { minutes.wrappedValue = Int($0.timeIntervalSince1970) / 60 % 1440 }
        )
        return HStack {
            Text(label).textStyle(Typography.cardTitle).foregroundStyle(Palette.textPrimary)
            Spacer()
            DatePicker("", selection: date, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                .environment(\.locale, Locale(identifier: "en_GB"))
                .accessibilityIdentifier(id)
        }
    }
}
