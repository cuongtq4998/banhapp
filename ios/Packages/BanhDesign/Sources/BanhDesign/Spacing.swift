import SwiftUI

public enum Spacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let inner: CGFloat = 14
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    /// Side margin of every screen.
    public static let screenMargin: CGFloat = 16
}

public enum Radius {
    public static let card: CGFloat = 28
    public static let cardRow: CGFloat = 20
    public static let bar: CGFloat = 36
    public static let field: CGFloat = 16
    public static let logo: CGFloat = 40
}

public enum Size {
    public static let touchTarget: CGFloat = 44
    public static let primaryButtonHeight: CGFloat = 52
    public static let secondaryButtonHeight: CGFloat = 56
    public static let logo: CGFloat = 132
    public static let logoGlyphRatio: CGFloat = 0.58
    public static let logoStrokeUnits: CGFloat = 3
    public static let barFloatOffset: CGFloat = 8
    public static let hairline: CGFloat = 1
    public static let badgeHeight: CGFloat = 24
    public static let otpCellWidth: CGFloat = 44
    public static let otpCellHeight: CGFloat = 52
    public static let otpGap: CGFloat = 8
}

public enum Motion {
    public static let short: TimeInterval = 0.15
    public static let medium: TimeInterval = 0.25
    public static let standardSpring = Animation.spring(response: 0.4, dampingFraction: 0.85)
    public static let toastDuration: Duration = .seconds(4)
    public static let pressedScale: CGFloat = 0.97
}
