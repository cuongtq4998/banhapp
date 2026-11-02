import XCTVapor
@testable import App

/// Address and installation budgets, cursor accounting, proxy header rule.
final class LookupLimitTests: LookupRouteTestCase {
    private let json: HTTPHeaders = ["Content-Type": "application/json"]
    private let installationID = "11111111-1111-4111-8111-111111111111"

    private func policy(address: Int = 100, installation: Int = 100, phone: Int = 100) -> LookupPolicy {
        var policy = LookupPolicy()
        policy.floorMilliseconds = 0
        policy.perAddressPerHour = address
        policy.perInstallationPerHour = installation
        policy.perPhonePerHour = phone
        return policy
    }

    private func status(phone number: String, headers: HTTPHeaders? = nil, cursor: String? = nil) async throws -> HTTPStatus {
        let cursorField = cursor.map { #","cursor":"\#($0)""# } ?? ""
        var result = HTTPStatus.ok
        try await lookup(#"{"phone":"\#(number)"\#(cursorField)}"#, headers: headers ?? json) { result = $0.status }
        return result
    }

    private func firstCursor() async throws -> String {
        store.plant(normalised, (1...12).map { .sample($0) })
        var cursor = ""
        try await lookup(#"{"phone":"\#(phone)"}"#) { res in
            let answer = try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any]
            cursor = answer?["next_cursor"] as? String ?? ""
        }
        return cursor
    }

    func testAddressLimitRefusesTheRequestAfterTheBudget() async throws {
        let budget = LookupPolicy.Default.perAddressPerHour
        try await start(policy: policy(address: budget))
        for n in 0..<budget { let s = try await status(phone: "09000\(String(format: "%05d", n))"); XCTAssertEqual(s, .ok) }
        let refused = try await status(phone: "0900099999")
        XCTAssertEqual(refused, .tooManyRequests)
    }

    func testInstallationLimitRefusesTheRequestAfterTheBudget() async throws {
        let budget = LookupPolicy.Default.perInstallationPerHour
        try await start(policy: policy(installation: budget))
        var headers = json
        headers.add(name: LookupRoutes.installationHeader, value: installationID)
        for n in 0..<budget { let s = try await status(phone: "09000\(String(format: "%05d", n))", headers: headers); XCTAssertEqual(s, .ok) }
        let refused = try await status(phone: "0900099999", headers: headers)
        XCTAssertEqual(refused, .tooManyRequests)
        let without = try await status(phone: "0900099998")
        XCTAssertEqual(without, .ok, "no installation id: only the other limits apply")
    }

    func testValidCursorSkipsThePhoneBudgetButCountsAgainstAddress() async throws {
        try await start(policy: policy(address: 2, phone: 1))
        let cursor = try await firstCursor()
        let second = try await status(phone: phone, cursor: cursor)
        XCTAssertEqual(second, .ok, "phone budget of 1 is already spent by the first page")
        let third = try await status(phone: phone, cursor: cursor)
        XCTAssertEqual(third, .tooManyRequests, "the cursor pages used the address budget of 2")
    }

    func testValidCursorCountsAgainstInstallation() async throws {
        try await start(policy: policy(installation: 2, phone: 1))
        var headers = json
        headers.add(name: LookupRoutes.installationHeader, value: installationID)
        store.plant(normalised, (1...12).map { .sample($0) })
        var cursor = ""
        try await lookup(#"{"phone":"\#(phone)"}"#, headers: headers) { res in
            let answer = try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any]
            cursor = answer?["next_cursor"] as? String ?? ""
        }
        let second = try await status(phone: phone, headers: headers, cursor: cursor)
        XCTAssertEqual(second, .ok)
        let third = try await status(phone: phone, headers: headers, cursor: cursor)
        XCTAssertEqual(third, .tooManyRequests)
    }

    func testSpoofedForwardedForIsIgnoredWithoutAConfiguredHeader() async throws {
        try await start(policy: policy(address: 2))
        for n in 0..<2 {
            var headers = json
            headers.add(name: "X-Forwarded-For", value: "203.0.113.\(n)")
            let s = try await status(phone: "090000000\(n)", headers: headers)
            XCTAssertEqual(s, .ok)
        }
        var spoofed = json
        spoofed.add(name: "X-Forwarded-For", value: "203.0.113.200")
        let refused = try await status(phone: "0900000009", headers: spoofed)
        XCTAssertEqual(refused, .tooManyRequests, "a new forwarded value must not give a new budget")
    }

    func testConfiguredHeaderUsesTheEntryAtTheTrustedHop() async throws {
        var tuned = policy(address: 1)
        tuned.clientAddressHeader = "X-Client-Address"
        tuned.trustedProxyHops = 1
        try await start(policy: tuned)
        func send(_ chain: String, _ number: String) async throws -> HTTPStatus {
            var headers = json
            headers.add(name: "X-Client-Address", value: chain)
            return try await status(phone: number, headers: headers)
        }
        let first = try await send("198.51.100.1, 203.0.113.7", "0900000001")
        XCTAssertEqual(first, .ok)
        // Same trusted entry, different client-supplied entry on the left.
        let sameClient = try await send("198.51.100.99, 203.0.113.7", "0900000002")
        XCTAssertEqual(sameClient, .tooManyRequests)
        let otherClient = try await send("198.51.100.1, 203.0.113.8", "0900000003")
        XCTAssertEqual(otherClient, .ok)
    }

    func testTwoTrustedHopsPickTheSecondFromTheRight() async throws {
        var tuned = policy(address: 1)
        tuned.clientAddressHeader = "X-Client-Address"
        tuned.trustedProxyHops = 2
        try await start(policy: tuned)
        var headers = json
        headers.add(name: "X-Client-Address", value: "10.0.0.1, 203.0.113.7, 192.0.2.1")
        let first = try await status(phone: "0900000001", headers: headers)
        XCTAssertEqual(first, .ok)
        var changedRight = json
        changedRight.add(name: "X-Client-Address", value: "10.0.0.2, 203.0.113.7, 192.0.2.9")
        let same = try await status(phone: "0900000002", headers: changedRight)
        XCTAssertEqual(same, .tooManyRequests)
    }
}
