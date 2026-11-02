import SwiftUI

/// Be Vietnam Pro (SIL OFL 1.1). The font files are registered by the app (`UIAppFonts`).
public enum AppFont {
    public enum Weight: String {
        case regular = "BeVietnamPro-Regular"
        case medium = "BeVietnamPro-Medium"
        case semibold = "BeVietnamPro-SemiBold"
        case bold = "BeVietnamPro-Bold"
    }

    /// A custom font that still follows Dynamic Type.
    public static func font(_ weight: Weight, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: textStyle)
    }
}

public struct TextStyle {
    public let font: Font
    public var tracking: CGFloat = 0

    public init(font: Font, tracking: CGFloat = 0) {
        self.font = font
        self.tracking = tracking
    }
}

extension View {
    public func textStyle(_ style: TextStyle) -> some View {
        font(style.font).tracking(style.tracking)
    }
}

/// Type scale of the design board plus `badge` and `code` of design-system 7.1.
public enum Typography {
    public static let screenTitle = TextStyle(font: AppFont.font(.bold, size: 34, relativeTo: .largeTitle), tracking: -0.5)
    public static let display = TextStyle(font: AppFont.font(.bold, size: 30, relativeTo: .title), tracking: -0.5)
    public static let heading = TextStyle(font: AppFont.font(.semibold, size: 20, relativeTo: .title3))
    public static let cardTitle = TextStyle(font: AppFont.font(.semibold, size: 15, relativeTo: .body))
    public static let body = TextStyle(font: AppFont.font(.regular, size: 15, relativeTo: .body))
    public static let bodyStrong = TextStyle(font: AppFont.font(.semibold, size: 15, relativeTo: .body))
    public static let button = TextStyle(font: AppFont.font(.semibold, size: 16, relativeTo: .body))
    public static let smallButton = TextStyle(font: AppFont.font(.semibold, size: 14, relativeTo: .subheadline))
    public static let caption = TextStyle(font: AppFont.font(.regular, size: 13, relativeTo: .footnote))
    public static let badge = TextStyle(font: AppFont.font(.bold, size: 12, relativeTo: .caption))
    public static let rowCode = TextStyle(font: AppFont.font(.bold, size: 15, relativeTo: .body))
    public static let otpDigit = TextStyle(font: AppFont.font(.semibold, size: 24, relativeTo: .title2).monospacedDigit())
}
