import SwiftUI

/// Month calendar for the receiving date (`DateGrid`). Custom, because the system date picker cannot
/// disable dates by capacity. Each day is one element with its spoken state (UI document 9).
struct DateGrid: View {
    private static let daysPerWeek = 7

    let model: DateViewModel
    let month: ShopDate

    var body: some View {
        VStack(spacing: Spacing.sm) {
            header
            weekdayRow
            // Plain stacks, not a lazy grid: a month is at most six rows, and every day must be in the
            // accessibility tree at once.
            ForEach(0..<weeks.count, id: \.self) { week in
                HStack(spacing: Spacing.xs) {
                    ForEach(0..<Self.daysPerWeek, id: \.self) { column in
                        if let date = weeks[week][column] {
                            DayCell(date: date, state: model.state(of: date), model: model)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 1).accessibilityHidden(true)
                        }
                    }
                }
            }
        }
    }

    /// The month as rows of seven, Monday first; days outside the month are nil.
    private var weeks: [[ShopDate?]] {
        let days: [ShopDate?] = Array(repeating: nil, count: month.firstOfMonth.weekdayIndex)
            + (1...month.daysInMonth).map { ShopDate(year: month.year, month: month.month, day: $0) }
        return stride(from: 0, to: days.count, by: Self.daysPerWeek).map { start in
            let row = Array(days[start..<min(start + Self.daysPerWeek, days.count)])
            return row + Array(repeating: nil, count: Self.daysPerWeek - row.count)
        }
    }

    private var header: some View {
        HStack {
            monthButton(symbol: "chevron.left", label: OrderStrings.monthPrevious, enabled: model.canShowPreviousMonth,
                        identifier: AccessibilityID.dateMonthPrevious, action: model.showPreviousMonth)
            Spacer()
            Text(verbatim: OrderStrings.format(OrderStrings.monthTitle, month.month, month.year))
                .textStyle(Typography.cardTitle)
                .foregroundStyle(Palette.textPrimary)
                .accessibilityIdentifier(AccessibilityID.dateMonthTitle)
            Spacer()
            monthButton(symbol: "chevron.right", label: OrderStrings.monthNext, enabled: model.canShowNextMonth,
                        identifier: AccessibilityID.dateMonthNext, action: model.showNextMonth)
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<OrderStrings.weekdays.count, id: \.self) { index in
                Text(OrderStrings.weekdays[index])
                    .textStyle(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func monthButton(
        symbol: String, label: LocalizedStringResource, enabled: Bool, identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .foregroundStyle(enabled ? Palette.textPrimary : Palette.textDisabled)
                .frame(width: Size.touchTarget, height: Size.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifier)
    }
}

private struct DayCell: View {
    @ScaledMetric(relativeTo: .body) private var height = Size.touchTarget

    let date: ShopDate
    let state: DayState
    let model: DateViewModel

    var body: some View {
        Button { model.select(date) } label: {
            Text(verbatim: String(date.day))
                .textStyle(state == .selected ? Typography.cardTitle : Typography.body)
                .foregroundStyle(state.isSelectable ? Palette.textPrimary : Palette.textDisabled)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(fill, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                        .strokeBorder(state == .selected ? Palette.primary : .clear, lineWidth: 2)
                }
                .overlay { if state == .full { Strike().stroke(Palette.textDisabled, lineWidth: Size.hairline) } }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!state.isSelectable)
        .accessibilityLabel(Text(verbatim: spokenLabel))
        .accessibilityAddTraits(state == .selected ? .isSelected : [])
        .accessibilityIdentifier(AccessibilityID.dateCell(date.iso))
    }

    private var fill: Color {
        switch state {
        case .selected: Palette.primaryContainer
        case .available: Palette.glassFill
        case .full, .tooSoon, .tooFar: .clear
        }
    }

    private var spokenLabel: String {
        let text = date.displayText
        switch state {
        case .available: return text
        case .selected: return OrderStrings.format(OrderStrings.dateSelected, text)
        case .full: return OrderStrings.format(OrderStrings.dateFull, text)
        case .tooSoon: return OrderStrings.format(OrderStrings.dateTooSoon, text, model.leadDays)
        case .tooFar: return OrderStrings.format(OrderStrings.dateTooFar, text, model.maxDaysAhead)
        }
    }
}

/// The diagonal line across a full day.
private struct Strike: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + Spacing.sm, y: rect.maxY - Spacing.sm))
        path.addLine(to: CGPoint(x: rect.maxX - Spacing.sm, y: rect.minY + Spacing.sm))
        return path
    }
}
