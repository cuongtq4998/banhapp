import SwiftUI

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
