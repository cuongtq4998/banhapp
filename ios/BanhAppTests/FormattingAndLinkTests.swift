import XCTest
@testable import BanhApp

final class FormattingAndLinkTests: XCTestCase {
    func testMoneyIsWholeDongWithDotSeparatorsAndTheDongSign() {
        XCTAssertEqual(MoneyFormatter.format(0), "0 ₫")
        XCTAssertEqual(MoneyFormatter.format(999), "999 ₫")
        XCTAssertEqual(MoneyFormatter.format(35_000), "35.000 ₫")
        XCTAssertEqual(MoneyFormatter.format(125_000), "125.000 ₫")
        XCTAssertEqual(MoneyFormatter.format(1_234_567), "1.234.567 ₫")
    }

    func testImageURLKeepsTheContentVersionQuery() {
        let base = URL(string: "https://api.example.invalid")!
        XCTAssertEqual(
            base.resolvingAsset("/assets/images/banana.png?v=a547ade3")?.absoluteString,
            "https://api.example.invalid/assets/images/banana.png?v=a547ade3"
        )
    }

    func testAFullImageURLIsKeptAsItIs() {
        let base = URL(string: "https://api.example.invalid")!
        XCTAssertEqual(
            base.resolvingAsset("https://cdn.example.invalid/a.png?v=1")?.absoluteString,
            "https://cdn.example.invalid/a.png?v=1"
        )
    }

    func testZaloLinkIsTheWebLinkOfADR0015() {
        XCTAssertEqual(ContactLinks.zaloURL(zaloContact: "84900000000")?.absoluteString, "https://zalo.me/84900000000")
        XCTAssertNil(ContactLinks.zaloURL(zaloContact: ""))
    }

    func testPhoneLinkKeepsTheE164Number() {
        XCTAssertEqual(ContactLinks.phoneURL(phoneContact: "+84900000000")?.absoluteString, "tel:+84900000000")
        XCTAssertNil(ContactLinks.phoneURL(phoneContact: ""))
    }

    func testSurfaceStyleFallsBackWhenGlassIsMissingOrAccessibilityAsksForOpacity() {
        typealias Style = SurfaceStyle
        XCTAssertEqual(Style.resolve(supportsLiquidGlass: true, reduceTransparency: false, increaseContrast: false), .liquidGlass)
        XCTAssertEqual(Style.resolve(supportsLiquidGlass: false, reduceTransparency: false, increaseContrast: false), .material)
        XCTAssertEqual(Style.resolve(supportsLiquidGlass: true, reduceTransparency: true, increaseContrast: false), .material)
        XCTAssertEqual(Style.resolve(supportsLiquidGlass: true, reduceTransparency: false, increaseContrast: true), .material)
    }
}
