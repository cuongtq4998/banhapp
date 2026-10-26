import SwiftUI

/// Gradient with two blurred blobs behind every screen. Static in every motion setting, so Reduce
/// Motion needs no special case.
struct AppBackground: View {
    private static let blobSize: CGFloat = 280
    private static let blobBlur: CGFloat = 60
    private static let blobOffset: CGFloat = 120

    var body: some View {
        LinearGradient(
            colors: [Palette.backgroundTop, Palette.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .topTrailing) { blob(Palette.blobGreen).offset(x: Self.blobOffset, y: -Self.blobOffset) }
        .overlay(alignment: .bottomLeading) { blob(Palette.blobCream).offset(x: -Self.blobOffset, y: Self.blobOffset) }
        .clipped()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func blob(_ color: Color) -> some View {
        Circle().fill(color).frame(width: Self.blobSize, height: Self.blobSize).blur(radius: Self.blobBlur)
    }
}

extension View {
    /// Puts the app background behind a screen. Each screen owns its background so the navigation
    /// transitions carry it along instead of showing the system colour underneath.
    func appBackground() -> some View {
        background { AppBackground() }
    }
}
