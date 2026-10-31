import SwiftUI

/// Which rendering a glass surface gets (ADR-0012, UI document section 6). One pure decision, so every
/// card, bar and button agrees and the rule is unit-testable.
nonisolated enum SurfaceStyle: Equatable {
    /// iOS 26 and later: Liquid Glass.
    case liquidGlass
    /// iOS 17 to 25, and any version with Reduce Transparency or Increase Contrast: system material
    /// over `color.surface.solid` with a hairline edge (`material.fallback`).
    case material

    static func resolve(supportsLiquidGlass: Bool, reduceTransparency: Bool, increaseContrast: Bool) -> SurfaceStyle {
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
