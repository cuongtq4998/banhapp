import SwiftUI

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
