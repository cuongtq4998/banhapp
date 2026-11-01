import SwiftUI

/// Six-digit code entry: six visible cells over one hidden text input (design-system 7.2). The cells are
/// hidden from VoiceOver; the input carries the label.
public struct OtpField: View {
    @Binding var code: String
    let label: LocalizedStringResource
    let identifier: String
    var isError: Bool
    var shakeTrigger: Int
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public static let length = 6

    public init(code: Binding<String>, label: LocalizedStringResource, identifier: String, isError: Bool, shakeTrigger: Int) {
        _code = code
        self.label = label
        self.identifier = identifier
        self.isError = isError
        self.shakeTrigger = shakeTrigger
    }

    /// Keeps digits only, at most six (a paste of "123 456" fills all cells).
    public static func sanitize(_ text: String) -> String {
        String(text.filter { $0.isASCII && $0.isNumber }.prefix(length))
    }

    public var body: some View {
        ZStack {
            HStack(spacing: Size.otpGap) {
                ForEach(0..<Self.length, id: \.self) { index in cell(index) }
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .opacity(0.02)
                .accessibilityLabel(Text(label))
                .accessibilityIdentifier(identifier)
                .onChange(of: code) { _, new in
                    let clean = Self.sanitize(new)
                    if clean != new { code = clean }
                }
        }
        .modifier(ShakeEffect(progress: reduceMotion ? 0 : CGFloat(shakeTrigger)))
        .animation(reduceMotion ? nil : .linear(duration: 0.3), value: shakeTrigger)
        .onAppear { focused = true }
        .onChange(of: shakeTrigger) { _, _ in focused = true }
    }

    private func cell(_ index: Int) -> some View {
        let digits = Array(code)
        let filled = index < digits.count
        return Text(verbatim: filled ? String(digits[index]) : "")
            .textStyle(Typography.otpDigit)
            .foregroundStyle(Palette.textPrimary)
            .frame(width: Size.otpCellWidth, height: Size.otpCellHeight)
            .background(Palette.surfaceSolid, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    .strokeBorder(isError ? Palette.error : (index == digits.count && focused ? Palette.primary : Palette.glassStroke), lineWidth: 2)
            }
    }
}

/// Shakes 4 pt, once per whole step of `progress`.
private struct ShakeEffect: GeometryEffect {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 4 * sin(progress * .pi * 4), y: 0))
    }
}
