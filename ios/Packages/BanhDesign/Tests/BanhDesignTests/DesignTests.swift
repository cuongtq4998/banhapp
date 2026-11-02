import Testing
@testable import BanhDesign

struct DesignTests {
    @Test func otpKeepsOnlySixAsciiDigits() {
        #expect(OtpField.sanitize("123 456") == "123456")
        #expect(OtpField.sanitize("1234567") == "123456")
        #expect(OtpField.sanitize("12a3") == "123")
        #expect(OtpField.sanitize("١٢٣") == "")
    }

    @Test func countBadgeShowsNinetyNinePlus() {
        #expect(CountBadge.label(for: 3) == "3")
        #expect(CountBadge.label(for: 99) == "99")
        #expect(CountBadge.label(for: 100) == "99+")
    }

    @Test func surfaceStyleFallsBackWhenTransparencyIsReduced() {
        #expect(SurfaceStyle.resolve(supportsLiquidGlass: true, reduceTransparency: false, increaseContrast: false) == .liquidGlass)
        #expect(SurfaceStyle.resolve(supportsLiquidGlass: true, reduceTransparency: true, increaseContrast: false) == .material)
        #expect(SurfaceStyle.resolve(supportsLiquidGlass: false, reduceTransparency: false, increaseContrast: false) == .material)
    }
}
