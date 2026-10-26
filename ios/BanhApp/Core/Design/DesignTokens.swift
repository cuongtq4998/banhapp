import SwiftUI

/// Tokens of docs/design/design-system.md section 2 (iOS column). Feature code uses these names only.
/// The design defines a light palette only, so the app pins the light appearance (see `RootView`).
enum Palette {
    static let primary = Color(hex: 0x2F6B3F)
    static let onPrimary = Color.white
    static let primaryContainer = Color(hex: 0xD6EBD9)
    static let onPrimaryContainer = Color(hex: 0x123A20)
    static let backgroundTop = Color(hex: 0xF3F7EA)
    static let backgroundBottom = Color(hex: 0xF8F1DD)
    static let blobGreen = Color(hex: 0x8FC79A).opacity(0.45)
    static let blobCream = Color(hex: 0xF1D9A0).opacity(0.45)
    static let surfaceSolid = Color(hex: 0xFBF8EE)
    static let surfaceStroke = Color.white.opacity(0.6)
    static let textPrimary = Color(hex: 0x1B2A1F)
    static let textSecondary = Color(hex: 0x4A5A4E)
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

enum Typography {
    static let display = Font.title.bold()
    static let titleLarge = Font.largeTitle.bold()
    static let titleMedium = Font.title3.weight(.semibold)
    static let body = Font.body
    static let bodyStrong = Font.body.weight(.semibold)
    static let label = Font.headline
    static let caption = Font.footnote
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let screenMargin: CGFloat = 20
}

enum Radius {
    static let card: CGFloat = 28
    static let field: CGFloat = 16
    static let image: CGFloat = 20
    static let logo: CGFloat = 30
}

enum Size {
    static let touchTarget: CGFloat = 44
    static let buttonHeight: CGFloat = 54
    static let thumb: CGFloat = 72
    static let logoLarge: CGFloat = 120
    static let logoSmall: CGFloat = 56
    /// The bar floats this far above the bottom safe area (design system, `elevation.bar`).
    static let barFloatOffset: CGFloat = 8
    /// Hairline edge of glass surfaces.
    static let hairline: CGFloat = 1
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
}

/// Card shadow of `elevation.card`: offset 8, blur 24, 10% black.
enum CardShadow {
    static let color = Color.black.opacity(0.1)
    static let radius: CGFloat = 24
    static let offsetY: CGFloat = 8
}
