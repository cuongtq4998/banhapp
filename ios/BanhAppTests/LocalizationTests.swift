import XCTest
@testable import BanhApp

/// Guards FR-14 and AC-29: every text is Vietnamese and comes from the catalog, and no customer-visible
/// text carries a sample marker.
final class LocalizationTests: XCTestCase {
    private static let forbiddenWords = ["mẫu", "sample", "test", "demo", "fake"]

    private let catalogURL = Fixtures.repositoryRoot.appendingPathComponent("ios/BanhApp/Localizable.xcstrings")
    private let stringsSourceURLs = ["Strings.swift", "OrderStrings.swift", "SendStrings.swift"].map {
        Fixtures.repositoryRoot.appendingPathComponent("ios/BanhApp/Core/Localization/\($0)")
    }

    private func catalogValues() throws -> [String: String] {
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: [String: Any]])
        return try strings.mapValues { entry in
            let vi = try XCTUnwrap((entry["localizations"] as? [String: Any])?["vi"] as? [String: Any])
            return try XCTUnwrap((vi["stringUnit"] as? [String: Any])?["value"] as? String)
        }
    }

    func testNoCatalogTextContainsASampleMarker() throws {
        for (key, value) in try catalogValues() {
            for word in Self.forbiddenWords {
                XCTAssertFalse(value.lowercased().contains(word), "\(key) contains \"\(word)\"")
            }
        }
    }

    func testEveryKeyUsedInStringsExistsInTheCatalog() throws {
        let source = try stringsSourceURLs.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
        let keys = source.matches(of: /LocalizedStringResource\("([A-Z0-9_]+)"\)/).map { String($0.1) }
        XCTAssertGreaterThanOrEqual(keys.count, 90)
        let catalog = try catalogValues()
        for key in keys {
            XCTAssertNotNil(catalog[key], "\(key) is missing from Localizable.xcstrings")
        }
    }

    func testTheAppBundleResolvesKeysToTheVietnameseText() throws {
        for (key, expected) in try catalogValues() where !expected.contains("%") {
            let resolved = String(localized: LocalizedStringResource(String.LocalizationValue(key)))
            XCTAssertEqual(resolved, expected, "\(key) did not resolve through the bundle")
        }
    }

    func testFormattedKeysFillTheirPlaceholders() {
        XCTAssertEqual(Strings.priceEach(amount: "35.000 ₫"), "35.000 ₫/cái")
        XCTAssertEqual(Strings.stepLabel(step: 1), "Bước 1/4")
        XCTAssertEqual(OrderStrings.format(OrderStrings.qtyTotal, 5), "Tổng số bánh: 5")
        XCTAssertEqual(OrderStrings.format(OrderStrings.qtyValue, "Bánh chuối", 2), "Bánh chuối, số lượng 2")
        XCTAssertEqual(OrderStrings.format(OrderStrings.slotLabel, "08:00", "10:00"), "08:00 – 10:00")
        XCTAssertEqual(OrderStrings.format(OrderStrings.noteCounter, 12, 200), "12/200")
        XCTAssertEqual(OrderStrings.format(OrderStrings.monthTitle, 11, 2026), "Tháng 11 năm 2026")
        XCTAssertEqual(OrderStrings.format(OrderStrings.errorNoteMax, 200), "Ghi chú tối đa 200 ký tự.")
        XCTAssertEqual(OrderStrings.format(OrderStrings.reviewItem, "Bánh chuối", 2), "Bánh chuối × 2")
        XCTAssertEqual(OrderStrings.format(OrderStrings.dateTooSoon, "03/11/2026", 2), "03/11/2026, chưa thể chọn vì cần đặt trước ít nhất 2 ngày")
    }

    func testSpokenDateAndDetailButton() {
        let date = ShopDate(year: 2026, month: 11, day: 4)
        XCTAssertEqual(date.spokenText, "ngày 4 tháng 11 năm 2026")
        XCTAssertEqual(OrderStrings.format(OrderStrings.dateAvailable, date.spokenText), "ngày 4 tháng 11 năm 2026, có thể chọn")
        XCTAssertEqual(String(localized: Strings.detailButtonOrder), "Đặt bánh")
    }

    func testNoOrderTextMentionsPayment() throws {
        // FR-19, AC-27.
        for (key, value) in try catalogValues() {
            for word in ["thanh toán", "chuyển khoản", "payment", "momo", "ngân hàng"] {
                XCTAssertFalse(value.lowercased().contains(word), "\(key) mentions payment")
            }
        }
    }
}
