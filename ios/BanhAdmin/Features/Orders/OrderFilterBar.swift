import BanhDesign
import SwiftUI

/// Search field and the one control row: six status chips and the date chip (FR-10, FR-11).
struct OrderFilterBar: View {
    @Bindable var model: OrderListViewModel
    @State private var showsDatePicker = false
    @State private var pickedDate = Date()
    @FocusState private var searchFocused: Bool

    private static let chips: [(OrderQuery.StatusFilter, LocalizedStringResource, String)] = [
        (.todo, AStrings.filterTodo, AdminID.filterTodo),
        (.new, AStrings.statusNew, AdminID.filterNew),
        (.confirmed, AStrings.statusConfirmed, AdminID.filterConfirmed),
        (.completed, AStrings.statusCompleted, AdminID.filterCompleted),
        (.cancelled, AStrings.statusCancelled, AdminID.filterCancelled),
        (.all, AStrings.filterAll, AdminID.filterAll),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            searchField
            if searchFocused && model.searchText.isEmpty {
                Text(AStrings.searchHint).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
            }
            if model.showsSearchMin {
                Text(AStrings.searchMin).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                    .accessibilityIdentifier(AdminID.ordersSearchMin)
            }
            chipRow
        }
        .sheet(isPresented: $showsDatePicker) { datePickerSheet }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.textSecondary).accessibilityHidden(true)
            TextField(String(localized: AStrings.searchPlaceholder), text: $model.searchText)
                .textStyle(Typography.body)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($searchFocused)
                .onSubmit { model.submitSearch() }
                .accessibilityIdentifier(AdminID.ordersSearch)
            if !model.searchText.isEmpty {
                Button { model.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.textSecondary)
                        .frame(width: Size.touchTarget, height: Size.touchTarget)
                }
                .accessibilityLabel(Text(AStrings.reset))
            }
        }
        .padding(.leading, Spacing.lg)
        .frame(minHeight: Size.touchTarget)
        .background(Palette.surfaceSolid, in: Capsule())
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(Self.chips, id: \.2) { filter, title, identifier in
                    Button { model.select(status: filter) } label: {
                        FilterChip(title: String(localized: title), isSelected: model.status == filter)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(identifier)
                }
                dateMenu
            }
        }
        .sensoryFeedback(.selection, trigger: model.status)
    }

    private var dateMenu: some View {
        Menu {
            Button(String(localized: AStrings.dateAll)) { model.select(date: .any) }.accessibilityIdentifier(AdminID.dateAll)
            Button(String(localized: AStrings.dateToday)) { model.select(date: .today) }.accessibilityIdentifier(AdminID.dateToday)
            Button(String(localized: AStrings.dateTomorrow)) { model.select(date: .tomorrow) }.accessibilityIdentifier(AdminID.dateTomorrow)
            Button(String(localized: AStrings.dateOne)) { showsDatePicker = true }.accessibilityIdentifier(AdminID.dateOne)
        } label: {
            FilterChip(title: dateTitle, isSelected: model.date != .any, showsChevron: true)
        }
        .accessibilityIdentifier(AdminID.filterDate)
    }

    private var dateTitle: String {
        switch model.date {
        case .any: String(localized: AStrings.filterDate)
        case .today: String(localized: AStrings.dateToday)
        case .tomorrow: String(localized: AStrings.dateTomorrow)
        case .day(let day): AdminFormatting.shortDate(day)
        }
    }

    private var datePickerSheet: some View {
        VStack(spacing: Spacing.lg) {
            DatePicker("", selection: $pickedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "vi_VN"))
            ActionButton(title: AStrings.save) {
                model.select(date: .day(AdminFormatting.wire(of: pickedDate)))
                showsDatePicker = false
            }
        }
        .padding(Spacing.lg)
        .presentationDetents([.medium])
    }
}
