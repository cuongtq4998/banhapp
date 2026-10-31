import SwiftUI

/// S-7, step 3 of 4: who receives the order and where.
struct RecipientStepView: View {
    @State var model: RecipientViewModel
    let privacy: PrivacyLink
    let onNext: () -> Void
    @FocusState private var focus: RecipientViewModel.Field?

    var body: some View {
        OrderStepScaffold(step: .recipient, title: OrderStrings.step3) {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                PrivacyNoticeCard(open: privacy.open)
                GlassCard { recipientFields }
                GlassCard { noteField }
            }
        } bar: {
            ActionButton(title: OrderStrings.commonNext, action: next)
                .disabled(!model.canContinue)
                .accessibilityIdentifier(AccessibilityID.orderNext)
        }
        .privacyPage(privacy)
        .onChange(of: model.focusRequest) { _, request in
            guard let request else { return }
            focus = request
            model.focusHandled()
        }
    }

    private func next() {
        if model.validateAll() { onNext() }
    }

    private var recipientFields: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            FormField(label: OrderStrings.fieldName, error: error(.name), errorIdentifier: AccessibilityID.fieldError("name")) {
                TextField("", text: binding(\.name, set: { $0.setName($1) }))
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($focus, equals: .name)
                    .onSubmit { focus = .phone }
                    .accessibilityLabel(Text(OrderStrings.fieldName))
                    .accessibilityIdentifier(AccessibilityID.fieldName)
            }
            FormField(label: OrderStrings.fieldPhone, error: error(.phone), errorIdentifier: AccessibilityID.fieldError("phone")) {
                TextField("", text: binding(\.phone, set: { $0.setPhone($1) }))
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($focus, equals: .phone)
                    .accessibilityLabel(Text(OrderStrings.fieldPhone))
                    .accessibilityIdentifier(AccessibilityID.fieldPhone)
            }
            FormField(label: OrderStrings.fieldAddress, error: error(.address), errorIdentifier: AccessibilityID.fieldError("address")) {
                TextField("", text: binding(\.address, set: { $0.setAddress($1) }), axis: .vertical)
                    .lineLimit(2...4)
                    .textContentType(.fullStreetAddress)
                    .focused($focus, equals: .address)
                    .accessibilityLabel(Text(OrderStrings.fieldAddress))
                    .accessibilityIdentifier(AccessibilityID.fieldAddress)
            }
            DistrictPicker(model: model)
        }
    }

    private var noteField: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            FormField(label: OrderStrings.fieldNote, error: error(.note), errorIdentifier: AccessibilityID.fieldError("note")) {
                TextField("", text: binding(\.note, set: { $0.setNote($1) }), axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focus, equals: .note)
                    .accessibilityLabel(Text(OrderStrings.fieldNote))
                    .accessibilityIdentifier(AccessibilityID.fieldNote)
            }
            Text(verbatim: OrderStrings.format(OrderStrings.noteCounter, model.noteLength, model.noteMaxLength))
                .textStyle(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityIdentifier(AccessibilityID.noteCounter)
        }
    }

    private func error(_ field: RecipientViewModel.Field) -> String? {
        switch model.problems[field] {
        case .nameRequired: String(localized: OrderStrings.errorNameRequired)
        case .phoneRequired: String(localized: OrderStrings.errorPhoneRequired)
        case .phoneInvalid: String(localized: OrderStrings.errorPhoneInvalid)
        case .addressRequired: String(localized: OrderStrings.errorAddressRequired)
        case .districtRequired: String(localized: OrderStrings.errorDistrictRequired)
        case .noteTooLong: OrderStrings.format(OrderStrings.errorNoteMax, model.noteMaxLength)
        case nil: nil
        }
    }

    private func binding(
        _ value: KeyPath<RecipientViewModel, String>, set: @escaping (RecipientViewModel, String) -> Void
    ) -> Binding<String> {
        Binding(get: { model[keyPath: value] }, set: { set(model, $0) })
    }
}
