import XCTest
@testable import BanhApp

/// Guards FR-14 and AC-29: every text is Vietnamese and comes from the catalog, and no customer-visible
/// text carries a sample marker.
final class LocalizationTests: XCTestCase {
    private static let forbiddenWords = ["mẫu", "sample", "test", "demo", "fake"]

    private let catalogURL = Fixtures.repositoryRoot.appendingPathComponent("ios/BanhApp/Localizable.xcstrings")
    private let stringsSourceURL = Fixtures.repositoryRoot.appendingPathComponent("ios/BanhApp/Core/Localization/Strings.swift")

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
        let source = try String(contentsOf: stringsSourceURL, encoding: .utf8)
        let keys = source.matches(of: /LocalizedStringResource\("([A-Z0-9_]+)"\)/).map { String($0.1) }
        XCTAssertGreaterThanOrEqual(keys.count, 19)
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
    }
}
