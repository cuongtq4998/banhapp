import SwiftUI

/// The district field (`PickerField`): shows the choice or a placeholder and opens a sheet that lists
/// the served districts with their flat fee. Only served districts are in the list (AC-11).
struct DistrictPicker: View {
    let model: RecipientViewModel
    @State private var isPresented = false

    var body: some View {
        FormField(
            label: OrderStrings.fieldDistrict, error: error, errorIdentifier: AccessibilityID.fieldError("district")
        ) {
            content
        }
        .sheet(isPresented: $isPresented) { sheet }
    }

    private var error: String? {
        model.problems[.district] == nil ? nil : String(localized: OrderStrings.errorDistrictRequired)
    }

    @ViewBuilder
    private var content: some View {
        switch model.districts {
        case .loading:
            HStack { ProgressView(); Text(Strings.commonLoading) }
                .accessibilityIdentifier(AccessibilityID.fieldDistrict)
        case .failed:
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(OrderStrings.districtError)
                    .accessibilityIdentifier(AccessibilityID.districtError)
                ActionButton(title: Strings.commonRetry, emphasis: .secondary) { Task { await model.retryDistricts() } }
                    .accessibilityIdentifier(AccessibilityID.errorRetry)
            }
        case .ready(let rows) where rows.isEmpty:
            Text(OrderStrings.districtEmpty).accessibilityIdentifier(AccessibilityID.districtEmpty)
        case .ready:
            Button { isPresented = true } label: {
                HStack {
                    if let district = model.selectedDistrict {
                        Text(verbatim: district.name)
                    } else {
                        Text(OrderStrings.districtPlaceholder).foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down").foregroundStyle(Palette.textSecondary).accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.fieldDistrict)
            if let district = model.selectedDistrict {
                Text(verbatim: OrderStrings.format(OrderStrings.districtFee, district.feeText))
                    .textStyle(Typography.caption)
                    .foregroundStyle(Palette.primaryDeep)
                    .accessibilityIdentifier(AccessibilityID.districtFee)
            }
        }
    }

    private var sheet: some View {
        NavigationStack {
            List {
                if case .ready(let rows) = model.districts {
                    ForEach(rows) { row in
                        Button {
                            model.select(row)
                            isPresented = false
                        } label: {
                            HStack {
                                Text(verbatim: row.name).foregroundStyle(Palette.textPrimary)
                                Spacer()
                                Text(verbatim: OrderStrings.format(OrderStrings.districtFee, row.feeText))
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            .textStyle(Typography.body)
                            .frame(minHeight: Size.touchTarget)
                        }
                        .accessibilityIdentifier(AccessibilityID.districtRow(row.id.identifierText))
                    }
                }
            }
            .navigationTitle(Text(OrderStrings.fieldDistrict))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
