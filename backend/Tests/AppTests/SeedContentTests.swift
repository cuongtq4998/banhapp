import XCTest
@testable import App

/// AC-29: sample values carry no marker word a customer could read. The flag
/// `is_sample` lives only in the database.
final class SeedContentTests: XCTestCase {
    private let markers = ["mẫu", "sample", "test", "demo", "fake"]

    private func assertNoMarker(in text: String, source: String, file: StaticString = #filePath, line: UInt = #line) {
        let lowered = text.lowercased()
        for marker in markers {
            XCTAssertFalse(lowered.contains(marker), "\(source) contains \(marker)", file: file, line: line)
        }
    }

    func testSeedValuesHaveNoMarkerWord() throws {
        let script = try String(contentsOf: TestPaths.seed, encoding: .utf8)
        // Comments and the `is_sample` column name are not customer-visible.
        let statements = script.split(separator: "\n")
            .filter { !$0.hasPrefix("--") }
            .joined(separator: "\n")
            .replacingOccurrences(of: "is_sample", with: "")
        assertNoMarker(in: statements, source: "sample.sql")
    }

    func testCatalogFixturesHaveNoMarkerWord() throws {
        for name in ["catalog-ok.json", "catalog-empty.json"] {
            let text = try String(contentsOf: TestPaths.contractFixtures.appendingPathComponent(name), encoding: .utf8)
            assertNoMarker(in: text, source: name)
        }
    }

    func testSeedContactsFollowTheSampleNumberPattern() throws {
        let script = try String(contentsOf: TestPaths.seed, encoding: .utf8)
        XCTAssertTrue(script.contains("'+84900000000'"))
        XCTAssertTrue(script.contains("'84900000000'"))
    }
}
