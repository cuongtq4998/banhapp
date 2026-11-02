import BanhDesign
import SwiftUI

/// The scroll view of the screen, so a field that gets the focus can scroll itself above the keyboard
/// and the floating save bar.
struct FormScrollKey: EnvironmentKey {
    static let defaultValue: ScrollViewProxy? = nil
}

extension EnvironmentValues {
    var formScroll: ScrollViewProxy? {
        get { self[FormScrollKey.self] }
        set { self[FormScrollKey.self] = newValue }
    }
}

extension View {
    /// Scrolls to this field (centred) when it takes the focus.
    func scrollsOnFocus(_ focus: FocusState<String?>.Binding, id: String, proxy: ScrollViewProxy?) -> some View {
        self.id(id).onChange(of: focus.wrappedValue) { _, new in
            guard new == id else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation { proxy?.scrollTo(id, anchor: .center) }
            }
        }
    }
}

/// A labelled text field with its error under it. `multiline` shows a counter against `limit`.
struct FormTextField: View {
    let label: LocalizedStringResource
    @Binding var text: String
    let identifier: String
    var error: String?
    var errorIdentifier = ""
    var keyboard: UIKeyboardType = .default
    var multiline = false
    var limit = 0
    var autocapitalize = true
    var focus: FocusState<String?>.Binding
    @Environment(\.formScroll) private var scroll

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            field.labeledField(label).scrollsOnFocus(focus, id: identifier, proxy: scroll)
            if multiline {
                Text(verbatim: AStrings.counter(text.count, max: limit)).textStyle(Typography.caption)
                    .foregroundStyle(Palette.textSecondary).frame(maxWidth: .infinity, alignment: .trailing)
            }
            if let error { FieldError(text: error, identifier: errorIdentifier) }
        }
    }

    @ViewBuilder
    private var field: some View {
        if multiline {
            TextField("", text: $text, axis: .vertical).lineLimit(3...6)
                // The whole box takes the tap, not only the first line of text.
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture { focus.wrappedValue = identifier }
                .focused(focus, equals: identifier)
                .accessibilityIdentifier(identifier)
        } else {
            TextField("", text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalize ? .sentences : .never)
                .autocorrectionDisabled(keyboard != .default)
                .focused(focus, equals: identifier)
                .accessibilityIdentifier(identifier)
        }
    }
}

/// Number pad field; thousand separators appear when the field loses focus.
struct NumberField: View {
    let label: LocalizedStringResource
    @Binding var text: String
    let identifier: String
    var error: String?
    var errorIdentifier = ""
    var suffix: String?
    var focus: FocusState<String?>.Binding
    @Environment(\.formScroll) private var scroll

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                TextField("", text: $text).keyboardType(.numberPad).focused(focus, equals: identifier)
                    .accessibilityIdentifier(identifier)
                if let suffix { Text(verbatim: suffix).foregroundStyle(Palette.textSecondary) }
            }
            .labeledField(label)
            .scrollsOnFocus(focus, id: identifier, proxy: scroll)
            if let error { FieldError(text: error, identifier: errorIdentifier) }
        }
        .onChange(of: focus.wrappedValue) { old, new in
            if new == identifier { text = FieldRules.digits(text) } else if old == identifier { text = FieldRules.grouped(text) }
        }
    }
}
