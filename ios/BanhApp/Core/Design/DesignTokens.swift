import SwiftUI

// The single source of every colour, size, radius, spacing and type value of the iOS app. The numbers
// come from the owner's design board (docs/design/reference/screens/ios-*.html, 390 x 844 points);
// feature code uses these names only and never a literal.

/// Colours of the design board. It defines a light palette only, so the app pins the light appearance
/// (see `RootView`).
enum Palette {
    static let primary = Color(hex: 0x2F6B3F)
    /// Top of the green gradient on primary buttons and tiles.
    static let primaryLight = Color(hex: 0x3F8A57)
    /// Prices, image-tile captions: the darker green of the board.
    static let primaryDeep = Color(hex: 0x1F5A33)
    static let onPrimary = Color.white
    static let primaryContainer = Color(hex: 0xD6EBD9)
    static let onPrimaryContainer = Color(hex: 0x123A20)

    static let backgroundTop = Color(hex: 0xE4F0E6)
    static let backgroundBottom = Color(hex: 0xF4EEDC)
    static let blobGreen = Color(hex: 0x7FC196).opacity(0.75)
    static let blobAmber = Color(hex: 0xF2C879).opacity(0.7)
    static let blobMint = Color(hex: 0xA6D8C4).opacity(0.7)

    /// Opaque stand-in for glass when Reduce Transparency or Increase Contrast is on.
    static let surfaceSolid = Color(hex: 0xFBF8EE)
    /// White wash of the glass fill that sits on the blurred background.
    static let glassFill = Color.white.opacity(0.52)
    static let glassStroke = Color.white.opacity(0.75)
    static let glassShadow = Color(hex: 0x1E462D).opacity(0.12)
    /// Image tile and chip edges.
    static let tileStroke = Color.white.opacity(0.8)
    static let imageTileTop = Color.white.opacity(0.8)
    static let imageTileBottom = Color(hex: 0x7FC196).opacity(0.5)

    static let buttonHighlight = Color.white.opacity(0.45)
    static let buttonShadow = Color(hex: 0x2F6B3F).opacity(0.35)

    static let textPrimary = Color(hex: 0x14231A)
    static let textSecondary = Color(hex: 0x3E5045)
    static let textDisabled = Color(hex: 0x7B857D)
    static let error = Color(hex: 0xB3261E)
    static let errorContainer = Color(hex: 0xFBE4E1)
    /// Disabled button fill: the primary text colour at 12%.
    static let disabledFill = textPrimary.opacity(0.12)
}

extension Color {
    fileprivate init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

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

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let cardGap: CGFloat = 12
    static let inner: CGFloat = 14
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    /// Side margin of every screen (board: 16).
    static let screenMargin: CGFloat = 16
    /// Gap between the status bar area and the first element of a screen (board: 76 less the 47 of the status bar on a 390 x 844 phone).
    static let homeHeaderTop: CGFloat = 28
    static let backButtonTop: CGFloat = 8
    /// Gap between the greeting and the first tile on the home screen.
    static let tilesTop: CGFloat = 56
    static let tileGap: CGFloat = 14
    static let tileInset: CGFloat = 24
    static let detailCardInset: CGFloat = 20
    static let detailCardGap: CGFloat = 10
    static let backButtonOffset: CGFloat = 12
    static let contactGap: CGFloat = 10
    /// Greeting text never grows wider than this (board: max-width 280).
    static let greetingMaxWidth: CGFloat = 280
}

enum Radius {
    static let card: CGFloat = 28
    static let bar: CGFloat = 36
    static let tile: CGFloat = 36
    static let detailCard: CGFloat = 32
    static let detailImage: CGFloat = 36
    static let thumb: CGFloat = 20
    static let field: CGFloat = 16
    static let logoLarge: CGFloat = 40
    static let logoSmall: CGFloat = 24
}

enum Size {
    static let touchTarget: CGFloat = 44
    static let backButton: CGFloat = 44
    static let primaryButtonHeight: CGFloat = 52
    static let secondaryButtonHeight: CGFloat = 56
    static let tileMinHeight: CGFloat = 132
    static let thumb: CGFloat = 84
    static let logoLarge: CGFloat = 132
    static let logoSmall: CGFloat = 72
    /// Glyph size inside the logo tile, relative to the tile side (board: 76 / 132 and 42 / 72).
    static let logoGlyphRatio: CGFloat = 0.58
    static let logoStrokeUnits: CGFloat = 3
    static let chevronTile: CGFloat = 26
    static let chevronRow: CGFloat = 20
    static let chevronBack: CGFloat = 20
    static let contactIcon: CGFloat = 18
    /// Cake picture on the detail screen: 358 x 330 on the board (390 wide less two 16 margins).
    static let detailImageAspect: CGFloat = 358.0 / 330.0
    /// The bar floats this far above the bottom safe area.
    static let barFloatOffset: CGFloat = 8
    static let hairline: CGFloat = 1
    static let iconStroke: CGFloat = 2.2
    static let placeholderIcon: CGFloat = 28
}

enum Motion {
    static let short: TimeInterval = 0.15
    static let medium: TimeInterval = 0.25
    static let long: TimeInterval = 0.4
    static let standardSpring = Animation.spring(response: 0.4, dampingFraction: 0.85)
    /// How long a `Toast` stays (design system, Toast component).
    static let toastDuration: Duration = .seconds(4)
    /// Scale of a pressed bar action.
    static let pressedScale: CGFloat = 0.97
    static let disabledOpacity: Double = 0.5
}

/// Background of every screen (board: 160 degree gradient and three blurred blobs).
enum BackgroundSpec {
    /// CSS 160deg on a 390 x 844 box, as unit points.
    static let gradientStart = UnitPoint(x: 0.095, y: -0.015)
    static let gradientEnd = UnitPoint(x: 0.905, y: 1.015)

    struct Blob {
        let color: Color
        let diameter: CGFloat
        let blur: CGFloat
        /// Centre as the distance from the nearest horizontal edge, and a fraction of the height (or the distance from the bottom).
        let centerX: CGFloat
        let anchorsTrailing: Bool
        let centerYFraction: CGFloat
    }

    // Centres derived from the board's top/left offsets: blob 1 at (80, 100), 2 at (340, 530), 3 at (90, 794) on 390 x 844.
    static let blobs: [Blob] = [
        Blob(color: Palette.blobGreen, diameter: 320, blur: 70, centerX: 80, anchorsTrailing: false, centerYFraction: 100.0 / 844),
        Blob(color: Palette.blobAmber, diameter: 300, blur: 80, centerX: 50, anchorsTrailing: true, centerYFraction: 530.0 / 844),
        Blob(color: Palette.blobMint, diameter: 260, blur: 70, centerX: 90, anchorsTrailing: false, centerYFraction: 794.0 / 844),
    ]
}

/// Glass of the board: `rgba(255,255,255,.52)`, blur 24, 1 px white edge, soft green shadow.
enum GlassSpec {
    static let shadowRadius: CGFloat = 16
    static let shadowOffsetY: CGFloat = 8
}

/// Shadow under a primary button.
enum ButtonShadow {
    static let radius: CGFloat = 8
    static let offsetY: CGFloat = 6
}
