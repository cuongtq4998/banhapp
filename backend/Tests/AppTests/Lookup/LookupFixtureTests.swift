import XCTVapor
@testable import App

/// Real lookup answers against the shared fixtures in `customer/`.
final class LookupFixtureTests: LookupRouteTestCase {
    private func fixture(_ name: String) throws -> NSDictionary {
        let url = TestPaths.contractFixtures.appendingPathComponent("customer/\(name).json")
        return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? NSDictionary ?? [:]
    }

    /// The cursor and request id change per run; everything else must be equal.
    private func stable(_ data: Data) throws -> NSDictionary {
        let object = try JSONSerialization.jsonObject(with: data) as? NSDictionary ?? [:]
        let copy = object.mutableCopy() as? NSMutableDictionary ?? [:]
        if let cursor = copy["next_cursor"], !(cursor is NSNull) { copy["next_cursor"] = "cursor" }
        if copy["request_id"] != nil { copy["request_id"] = "id" }
        return copy
    }

    private func expectSame(_ scenarioName: String, _ file: String, status: Int) async throws {
        try await app?.asyncShutdown(); app = nil
        let (code, data) = try await scenario(scenarioName)
        XCTAssertEqual(code, status, file)
        XCTAssertEqual(try stable(data), try stable(JSONSerialization.data(withJSONObject: fixture(file))), file)
    }

    func testAnswersMatchTheFixtures() async throws {
        for name in ["open", "fee-zero", "fee-corrected", "cancelled", "empty", "page-one", "last-page"] {
            try await expectSame("answer-\(name)", "order-lookup-answer-\(name)", status: 200)
        }
    }

    func testErrorsMatchTheFixtures() async throws {
        for name in ["phone-required", "phone-invalid", "cursor-invalid"] {
            try await expectSame("error-lookup-\(name)", "error-lookup-\(name)", status: 422)
        }
        try await expectSame("error-lookup-rate-limited", "error-lookup-rate-limited", status: 429)
    }

    func testRequestFixtureNormalisesToThePlantedPhone() throws {
        XCTAssertEqual(try fixture("order-lookup-request")["phone"] as? String, normalised)
    }
}
