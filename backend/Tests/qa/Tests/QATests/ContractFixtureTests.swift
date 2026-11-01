import XCTest
@testable import AppUnderTest

final class ContractFixtureTests: XCTestCase {

    // MARK: Contract fixtures (architecture.md 11 slice 1: catalog-*.json)

    func testTC1_CatalogFixturesExistAndSatisfyTheContractCheck() throws {
        let ok = try J.parse(Data(contentsOf: QAPaths.fixtures.appendingPathComponent("catalog-ok.json")))
        XCTAssertEqual(Slice1.shapeProblems(ok), [], "catalog-ok.json")
        XCTAssertEqual(Slice1.forbiddenHits(in: ok.allText), [], "catalog-ok.json")

        // AC-33: zero active cakes, districts and slots is a valid 200 with empty lists.
        let empty = try J.parse(Data(contentsOf: QAPaths.fixtures.appendingPathComponent("catalog-empty.json")))
        XCTAssertEqual(Slice1.shapeProblems(empty, productCount: 0, minDistricts: 0, minSlots: 0), [], "catalog-empty.json")
        XCTAssertEqual(empty["products"]?.array?.count, 0)
        XCTAssertEqual(Slice1.forbiddenHits(in: empty.allText), [], "catalog-empty.json")
    }

    func testTC3_NotModifiedFixtureFollowsTheEtagContract() throws {
        let json = try J.parse(Data(contentsOf: QAPaths.fixtures.appendingPathComponent("catalog-not-modified.json")))
        XCTAssertEqual(json["status"]?.int, 304)
        XCTAssertEqual(json["body"], J.null, "a 304 has no body")
        let sent = try XCTUnwrap(json["request_headers"]?["If-None-Match"]?.string)
        let etag = try XCTUnwrap(json["response_headers"]?["ETag"]?.string)
        XCTAssertEqual(sent, etag, "a 304 repeats the matched tag")
        XCTAssertEqual(json["response_headers"]?["Cache-Control"]?.string, "no-cache")
        XCTAssertNotNil(etag.range(of: "^\"[0-9a-f]{32}\"$", options: .regularExpression), "api.md 4.1: quoted 32 lowercase hex characters: \(etag)")
        XCTAssertNil(json["response_headers"]?["Content-Type"], "a 304 does not repeat Content-Type")
    }

    /// The README documents a family of files with one glob row (`order-error-*.json`) and names the
    /// members inside it, so a file is described when it is named or matches a glob row and its
    /// short name (without prefix and suffix) appears in that row. Same rule for admin/.
    func testExtra_FixtureReadmeListsEveryFixture() throws {
        let readme = try String(contentsOf: QAPaths.fixtures.appendingPathComponent("README.md"), encoding: .utf8)
        let rows = readme.split(separator: "\n").map(String.init).filter { $0.hasPrefix("|") }
        let globs = rows.compactMap { row -> (prefix: String, row: String)? in
            guard let range = row.range(of: "`[a-z-]+-\\*\\.json`", options: .regularExpression) else { return nil }
            let name = row[range].dropFirst().dropLast().replacingOccurrences(of: "*.json", with: "")
            return (name, row)
        }
        func described(_ file: String) -> Bool {
            let stem = file.replacingOccurrences(of: ".json", with: "")
            if readme.contains(file) || readme.contains("`\(stem)`") { return true }
            // Abbreviated lists such as "`error-a`, `-b`, `-c`" name later members by their tail only.
            if stem.hasPrefix("error-"), readme.contains("`-\(stem.dropFirst(6))`") { return true }
            return globs.contains { stem.hasPrefix($0.prefix) && $0.row.contains(String(stem.dropFirst($0.prefix.count))) }
        }
        let top = try FileManager.default.contentsOfDirectory(atPath: QAPaths.fixtures.path).filter { $0.hasSuffix(".json") }
        XCTAssertGreaterThanOrEqual(top.count, 10)
        for file in top { XCTAssertTrue(described(file), "\(file) is not described in contracts/fixtures/README.md") }
        let adminPath = QAPaths.fixtures.appendingPathComponent("admin").path
        for file in try FileManager.default.contentsOfDirectory(atPath: adminPath).filter({ $0.hasSuffix(".json") }) {
            XCTAssertTrue(described(file), "admin/\(file) is not described in contracts/fixtures/README.md")
        }
    }

    // MARK: Static scan of the sample data (TC-66, AC-29)

    func testTC66_SampleSeedTextHasNoVisibleSampleMarker() throws {
        let seed = try String(contentsOf: QAPaths.seed, encoding: .utf8)
        let literals = seed.components(separatedBy: "'").enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
        XCTAssertEqual(Slice1.forbiddenHits(in: literals.filter { !$0.hasPrefix("00000000-") && $0 != "Asia/Ho_Chi_Minh" }), [])
    }

}
