import SwiftUI

/// Gradient with three blurred blobs behind every screen. Static in every motion setting.
public struct AppBackground: View {
    private struct Blob {
        let color: Color
        let diameter: CGFloat
        let blur: CGFloat
        let centerX: CGFloat
        let anchorsTrailing: Bool
        let centerYFraction: CGFloat
    }

    private static let blobs = [
        Blob(color: Palette.blobGreen, diameter: 320, blur: 70, centerX: 80, anchorsTrailing: false, centerYFraction: 100.0 / 844),
        Blob(color: Palette.blobAmber, diameter: 300, blur: 80, centerX: 50, anchorsTrailing: true, centerYFraction: 530.0 / 844),
        Blob(color: Palette.blobMint, diameter: 260, blur: 70, centerX: 90, anchorsTrailing: false, centerYFraction: 794.0 / 844),
    ]

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Palette.backgroundTop, Palette.backgroundBottom],
                    startPoint: UnitPoint(x: 0.095, y: -0.015), endPoint: UnitPoint(x: 0.905, y: 1.015)
                )
                ForEach(Array(Self.blobs.enumerated()), id: \.offset) { _, blob in
                    Circle()
                        .fill(blob.color)
                        .frame(width: blob.diameter, height: blob.diameter)
                        .blur(radius: blob.blur)
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
    /// Puts the app background behind a screen.
    public func appBackground() -> some View {
        background { AppBackground() }
    }
}
