import BanhDesign
import SwiftUI

/// S-A14 Schedule or change the expected delivery date; only the server window is selectable.
struct DateSheet: View {
    @Bindable var model: OrderDetailViewModel
    @Environment(\.dismiss) private var dismiss

    private var change: Bool { model.dateEntry?.current != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(verbatim: AStrings.scheduleTitle(code: model.code, change: change)).textStyle(Typography.heading)
                    .foregroundStyle(Palette.textPrimary).accessibilityAddTraits(.isHeader)
                reference
                if let entry = model.dateEntry, let range = entry.range { picker(range: range) }
                Text(AStrings.scheduleHelp).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                if let text = errorText {
                    InlineMessage(kind: .error, text: text).accessibilityIdentifier(AdminID.scheduleError)
                }
            }
            .padding(Spacing.lg)
        }
        .bottomActionBar {
            VStack(spacing: Spacing.sm) {
                ActionButton(
                    title: change ? AStrings.rescheduleSave : AStrings.scheduleSave,
                    showsProgress: model.running == .scheduleDelivery || model.running == .changeDate
                ) { Task { await change ? model.changeDate() : model.scheduleDelivery() } }
                .disabled(model.isBusy || !(model.dateEntry?.canSave ?? false))
                .accessibilityIdentifier(AdminID.scheduleSave)
                ActionButton(title: AStrings.back, emphasis: .secondary) { dismiss() }
                    .accessibilityIdentifier(AdminID.scheduleBack)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .background(Palette.surfaceSolid.ignoresSafeArea())
        .accessibilityIdentifier(AdminID.scheduleSheet)
    }

    private var reference: some View {
        GlassCard(cornerRadius: Radius.card) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let detail = model.detail {
                    Text(verbatim: "\(String(localized: AStrings.requestedDate)): \(AdminFormatting.weekdayAndDate(detail.requestedDeliveryDate ?? detail.deliveryDate)) · \(detail.slot.text)")
                    if let expected = detail.expectedDeliveryDate {
                        Text(verbatim: "\(String(localized: AStrings.expectedDate)): \(AdminFormatting.weekdayAndDate(expected))")
                    }
                }
            }
            .textStyle(Typography.body).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func picker(range: DateRange) -> some View {
        let bounds = AdminFormatting.pickerDate(range.min)...AdminFormatting.pickerDate(range.max)
        let binding = Binding<Date>(
            get: { AdminFormatting.pickerDate(model.dateEntry?.chosen ?? range.min) },
            set: { model.dateEntry?.chosen = AdminFormatting.wire(of: $0) }
        )
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(verbatim: AdminFormatting.weekdayAndDate(model.dateEntry?.chosen ?? range.min)).textStyle(Typography.bodyStrong)
            DatePicker("", selection: binding, in: bounds, displayedComponents: .date)
                .datePickerStyle(.graphical).environment(\.calendar, AdminFormatting.shopCalendar)
                .environment(\.timeZone, AdminFormatting.shopTimeZone)
                .accessibilityIdentifier(AdminID.schedulePicker)
            Text(verbatim: AStrings.dateLimit(first: AdminFormatting.shortDate(range.min), last: AdminFormatting.shortDate(range.max)))
                .textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                .accessibilityIdentifier(AdminID.scheduleLimit)
        }
    }

    private var errorText: String? {
        switch model.entryError {
        case .datePast?: String(localized: AStrings.errDatePast)
        case .dateTooFar?: String(localized: AStrings.errDateTooFar)
        case .dateUnchanged?: String(localized: AStrings.errStatus)
        default: model.actionMessage == nil ? nil : model.messageText
        }
    }
}
