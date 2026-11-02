import SwiftUI

/// Colours of the design board and the admin additions (design-system 7.1). Light palette only.
public enum Palette {
    public static let primary = Color(hex: 0x2F6B3F)
    public static let primaryLight = Color(hex: 0x3F8A57)
    public static let onPrimary = Color.white
    public static let primaryContainer = Color(hex: 0xD6EBD9)
    public static let accentText = Color(hex: 0x123A20)

    static let backgroundTop = Color(hex: 0xE4F0E6)
    static let backgroundBottom = Color(hex: 0xF4EEDC)
    static let blobGreen = Color(hex: 0x7FC196).opacity(0.75)
    static let blobAmber = Color(hex: 0xF2C879).opacity(0.7)
    static let blobMint = Color(hex: 0xA6D8C4).opacity(0.7)

    /// Opaque stand-in for glass when Reduce Transparency or Increase Contrast is on.
    public static let surfaceSolid = Color(hex: 0xFBF8EE)
    static let glassFill = Color.white.opacity(0.52)
    static let glassStroke = Color.white.opacity(0.75)
    static let glassShadow = Color(hex: 0x1E462D).opacity(0.12)
    static let buttonHighlight = Color.white.opacity(0.45)
    static let buttonShadow = Color(hex: 0x2F6B3F).opacity(0.35)

    public static let textPrimary = Color(hex: 0x14231A)
    public static let textSecondary = Color(hex: 0x3E5045)
    public static let textDisabled = Color(hex: 0x7B857D)
    public static let error = Color(hex: 0xB3261E)
    public static let errorContainer = Color(hex: 0xFBE4E1)
    public static let warningContainer = Color(hex: 0xFFF1CC)
    public static let disabledFill = textPrimary.opacity(0.12)
    public static let chipFill = textPrimary.opacity(0.08)

    // Status badges (design-system 7.1).
    public static let statusNewFill = Color(hex: 0xFFF1CC)
    public static let statusNewText = Color(hex: 0x5C4400)
    public static let statusConfirmedFill = Color(hex: 0xD4EBDB)
    public static let statusConfirmedText = accentText
    public static let statusCompletedFill = Color(hex: 0x14231A).opacity(0.08)
    public static let statusCompletedText = textSecondary
    public static let statusCancelledFill = errorContainer
    public static let statusCancelledText = error

    // Red "due" mark and the number on the Orders tab.
    public static let dueText = error
    public static let dueFill = errorContainer
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
