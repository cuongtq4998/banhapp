import SwiftUI

/// Which rendering a glass surface gets (ADR-0012). One pure decision so every card, bar and button agrees.
public enum SurfaceStyle: Equatable {
    /// iOS 26 and later: Liquid Glass.
    case liquidGlass
    /// iOS 17 to 25, and any version with Reduce Transparency or Increase Contrast: material fallback.
    case material

    public static func resolve(supportsLiquidGlass: Bool, reduceTransparency: Bool, increaseContrast: Bool) -> SurfaceStyle {
        supportsLiquidGlass && !reduceTransparency && !increaseContrast ? .liquidGlass : .material
    }

    static var supportsLiquidGlass: Bool {
        if #available(iOS 26, *) { true } else { false }
    }
}

extension EnvironmentValues {
    var surfaceStyle: SurfaceStyle {
        SurfaceStyle.resolve(
            supportsLiquidGlass: SurfaceStyle.supportsLiquidGlass,
            reduceTransparency: accessibilityReduceTransparency,
            increaseContrast: colorSchemeContrast == .increased
        )
    }
}
