import SwiftUI

/// Gradient with three blurred blobs behind every screen, as on the design board. Static in every
/// motion setting, so Reduce Motion needs no special case.
struct AppBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Palette.backgroundTop, Palette.backgroundBottom],
                    startPoint: BackgroundSpec.gradientStart,
                    endPoint: BackgroundSpec.gradientEnd
                )
                ForEach(Array(BackgroundSpec.blobs.enumerated()), id: \.offset) { _, blob in
                    Circle()
                        .fill(blob.color)
                        .frame(width: blob.diameter, height: blob.diameter)
                        .blur(radius: blob.blur)
                        // Blobs hold their distance from the edge they hang on and their height fraction,
                        // so a taller or wider phone keeps the same composition.
                        .position(
                            x: blob.anchorsTrailing ? proxy.size.width - blob.centerX : blob.centerX,
                            y: proxy.size.height * blob.centerYFraction
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    /// Puts the app background behind a screen. Each screen owns its background so the navigation
    /// transitions carry it along instead of showing the system colour underneath.
    func appBackground() -> some View {
        background { AppBackground() }
    }
}
