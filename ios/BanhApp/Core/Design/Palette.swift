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
    /// Behind an amount that changed (`color.warningContainer`, UI document 5.8).
    static let warningContainer = Color(hex: 0xFFF1CC)
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
