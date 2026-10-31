import SwiftUI

/// Be Vietnam Pro (SIL Open Font License 1.1, files and licence in `Resources/Fonts`).
enum AppFont {
    enum Weight: String {
        case regular = "BeVietnamPro-Regular"
        case medium = "BeVietnamPro-Medium"
        case semibold = "BeVietnamPro-SemiBold"
        case bold = "BeVietnamPro-Bold"
    }

    /// A custom font that still follows Dynamic Type: `size` is the design size at the default text
    /// size and scales like the system `textStyle`.
    static func font(_ weight: Weight, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: textStyle)
    }
}

/// A font plus the letter spacing the design gives it (SwiftUI fonts do not carry tracking).
struct TextStyle {
    let font: Font
    var tracking: CGFloat = 0
}

extension View {
    func textStyle(_ style: TextStyle) -> some View {
        font(style.font).tracking(style.tracking)
    }
}

/// Type scale of the design board. Sizes are the board's point sizes at the default text size.
enum Typography {
    static let screenTitle = TextStyle(font: AppFont.font(.bold, size: 34, relativeTo: .largeTitle), tracking: -0.5)
    static let heroTitle = TextStyle(font: AppFont.font(.bold, size: 30, relativeTo: .title), tracking: -0.5)
    static let detailTitle = TextStyle(font: AppFont.font(.bold, size: 26, relativeTo: .title2), tracking: -0.3)
    static let tileTitle = TextStyle(font: AppFont.font(.bold, size: 22, relativeTo: .title3))
    static let heading = TextStyle(font: AppFont.font(.semibold, size: 20, relativeTo: .title3))
    static let detailPrice = TextStyle(font: AppFont.font(.bold, size: 18, relativeTo: .headline))
    static let cardTitle = TextStyle(font: AppFont.font(.semibold, size: 15, relativeTo: .body))
    static let body = TextStyle(font: AppFont.font(.regular, size: 15, relativeTo: .body))
    static let button = TextStyle(font: AppFont.font(.semibold, size: 16, relativeTo: .body))
    static let contactButton = TextStyle(font: AppFont.font(.semibold, size: 14, relativeTo: .subheadline))
    static let listPrice = TextStyle(font: AppFont.font(.bold, size: 13, relativeTo: .footnote))
    static let caption = TextStyle(font: AppFont.font(.regular, size: 13, relativeTo: .footnote))
    static let cardDescription = TextStyle(font: AppFont.font(.regular, size: 12, relativeTo: .caption))
}
