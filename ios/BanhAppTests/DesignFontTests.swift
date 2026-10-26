import UIKit
import XCTest
@testable import BanhApp

/// The design's typeface ships inside the app and is registered through `UIAppFonts`; a missing file or
/// a wrong PostScript name would silently fall back to the system font.
final class DesignFontTests: XCTestCase {
    func testEveryBundledWeightIsRegistered() {
        for weight in [AppFont.Weight.regular, .medium, .semibold, .bold] {
            XCTAssertNotNil(UIFont(name: weight.rawValue, size: 15), "\(weight.rawValue) is not registered")
        }
    }

    func testTheFontCoversVietnameseLetters() throws {
        let font = try XCTUnwrap(UIFont(name: AppFont.Weight.regular.rawValue, size: 15))
        let set = font.fontDescriptor.object(forKey: .characterSet) as? CharacterSet
        for scalar in "ẳặỡữđĐ".unicodeScalars {
            XCTAssertTrue(set?.contains(scalar) ?? false, "missing \(scalar)")
        }
    }
}
