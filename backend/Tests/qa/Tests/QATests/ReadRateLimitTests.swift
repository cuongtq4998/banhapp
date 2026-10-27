import XCTest
import XCTVapor
@testable import AppUnderTest

final class ReadRateLimitTests: XCTestCase {
    private var app: Application!

    override func setUp() async throws {
        app = try await CatalogApp.makeWithoutDatabase()
    }

    override func tearDown() async throws { try await app.asyncShutdown() }

    /// TC-50, boundary 120 per minute. `/healthz` is in the read group (api.md 1).
    func testTC50_The121stReadInAMinuteIsRateLimited() async throws {
        for i in 1...120 {
            let r = try await app.qaSend(.GET, "healthz")
            XCTAssertEqual(r.status, .ok, "request \(i) is inside the budget")
            if r.status != .ok { return }
        }
        let limited = try await app.qaSend(.GET, "healthz")
        XCTAssertEqual(limited.status, .tooManyRequests)
        XCTAssertEqual(Slice1.envelopeProblems(limited, code: "RATE_LIMITED", messageKey: "ERR_RATE_LIMITED"), [])
        let after = try XCTUnwrap(limited.header("Retry-After").flatMap(Int.init), "Retry-After must be an integer number of seconds")
        XCTAssertTrue((1...60).contains(after), "Retry-After \(after) must be within the 60 s window")
        XCTAssertEqual(limited.json?["error"]?["details"]?["retry_after_seconds"]?.int, after)
        XCTAssertEqual(limited.header("Cache-Control")?.lowercased().contains("no-store") ?? true, true, "a 429 must not be cached")
        XCTAssertNil(limited.header("ETag"))
    }

    /// The table in api.md 1: GET /v1/*, /healthz, /privacy and /assets/* share 120 per minute (ADR-0017).
    func testExtra_ReadGroupIsOneSharedBudget() async throws {
        let paths = ["healthz", "v1/catalog", "privacy", "assets/images/banana.png"]
        for i in 0..<120 { _ = try await app.qaSend(.GET, paths[i % paths.count]) }
        let r = try await app.qaSend(.GET, "v1/catalog")
        XCTAssertEqual(r.status, .tooManyRequests, "121st read across the group")
    }

    /// ADR-0017: 404 and 304 count, a 429 does not.
    func testExtra_NotFoundCountsAndALimitedRequestDoesNot() async throws {
        let small = try await CatalogApp.makeWithoutDatabase(CatalogApp.config(databaseURL: nil, readLimit: 3))
        defer { Task { try? await small.asyncShutdown() } }
        for path in ["nothing", "v1/nothing", "assets/images/none.png"] {
            let r = try await small.qaSend(.GET, path)
            XCTAssertEqual(r.status, .notFound, path)
        }
        let first = try await small.qaSend(.GET, "healthz")
        XCTAssertEqual(first.status, .tooManyRequests, "three 404s used the budget")
        let again = try await small.qaSend(.GET, "healthz")
        XCTAssertEqual(again.header("Retry-After"), first.header("Retry-After"), "refused requests do not move the window")
    }

    /// Window and Retry-After with a controlled clock (api.md 1: whole seconds left, rounded up, 1 to 60).
    func testExtra_WindowEdgesAndRetryAfterRounding() async throws {
        let small = try await CatalogApp.makeWithoutDatabase(CatalogApp.config(databaseURL: nil, readLimit: 2))
        defer { Task { try? await small.asyncShutdown() } }
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        func at(_ offset: TimeInterval) { small.services.clock = FixedWallClock(instant: t0.addingTimeInterval(offset)) }
        at(0)
        for _ in 0..<2 { let r = try await small.qaSend(.GET, "healthz"); XCTAssertEqual(r.status, .ok) }
        for (offset, expected) in [(0.0, 60), (0.4, 60), (0.5, 60), (0.6, 60), (30.2, 30), (59.0, 1), (59.9, 1)] as [(TimeInterval, Int)] {
            at(offset)
            let r = try await small.qaSend(.GET, "healthz")
            XCTAssertEqual(r.status, .tooManyRequests, "offset \(offset)")
            XCTAssertEqual(r.header("Retry-After").flatMap(Int.init), expected, "offset \(offset)")
        }
        at(59.999)
        let beforeEdge = try await small.qaSend(.GET, "healthz")
        XCTAssertEqual(beforeEdge.status, .tooManyRequests)
        at(60)
        let afterEdge = try await small.qaSend(.GET, "healthz")
        XCTAssertEqual(afterEdge.status, .ok, "a new window starts exactly 60 s after the first counted request")
        // the clock moving backwards (an adjustment) must not lock a client out
        at(-3_600)
        let backwards = try await small.qaSend(.GET, "healthz")
        XCTAssertEqual(backwards.status, .ok)
    }

    /// api.md 1 (v1.6): the window is 60 s starting at the first counted request OF THAT ADDRESS.
    /// A second address that first appears late in the first address's window gets its own full 60 s.
    func testExtra_EachAddressHasItsOwnWindow() async throws {
        let proxied = try await CatalogApp.makeWithoutDatabase(CatalogApp.config(databaseURL: nil, trustProxy: true, readLimit: 2))
        defer { Task { try? await proxied.asyncShutdown() } }
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        proxied.services.clock = FixedWallClock(instant: t0)
        _ = try await proxied.qaSend(.GET, "healthz", headers: ["X-Forwarded-For": "203.0.113.1"])
        proxied.services.clock = FixedWallClock(instant: t0.addingTimeInterval(50))
        for _ in 0..<2 { _ = try await proxied.qaSend(.GET, "healthz", headers: ["X-Forwarded-For": "203.0.113.2"]) }
        let limited = try await proxied.qaSend(.GET, "healthz", headers: ["X-Forwarded-For": "203.0.113.2"])
        XCTAssertEqual(limited.status, .tooManyRequests)
        XCTAssertEqual(limited.header("Retry-After"), "60", "second address started its window at t0+50, so 60 s are left")
    }

    func testExtra_SpoofedForwardedForHeaderDoesNotResetTheBudgetByDefault() async throws {
        // TRUST_PROXY is off by default (ADR-0014): the forwarded header must be ignored.
        for i in 0..<120 { _ = try await app.qaSend(.GET, "healthz", headers: ["X-Forwarded-For": "203.0.113.\(i % 250)"]) }
        let r = try await app.qaSend(.GET, "healthz", headers: ["X-Forwarded-For": "198.51.100.77"])
        XCTAssertEqual(r.status, .tooManyRequests)
    }

    // MARK: TRUST_PROXY=true

    private func proxied(limit: Int = 2) async throws -> Application {
        try await CatalogApp.makeWithoutDatabase(CatalogApp.config(databaseURL: nil, trustProxy: true, readLimit: limit))
    }

    private func status(_ app: Application, _ forwarded: String?) async throws -> HTTPResponseStatus {
        try await app.qaSend(.GET, "healthz", headers: forwarded.map { ["X-Forwarded-For": $0] } ?? [:]).status
    }

    func testExtra_TrustedProxyKeysTheBudgetOnTheLastForwardedEntry() async throws {
        let app = try await proxied()
        defer { Task { try? await app.asyncShutdown() } }
        for _ in 0..<2 { let ok = try await status(app, "203.0.113.10"); XCTAssertEqual(ok, .ok) }
        let limited = try await status(app, "203.0.113.10")
        XCTAssertEqual(limited, .tooManyRequests)
        let other = try await status(app, "203.0.113.11")
        XCTAssertEqual(other, .ok, "another client address has its own budget")
        // A client cannot pick its identity by writing entries in front of the proxy's one.
        for i in 0..<5 {
            let forged = "198.51.100.\(i), 203.0.113.10"
            let s = try await status(app, forged)
            XCTAssertEqual(s, .tooManyRequests, "forged leading entry \(i) must not escape the budget of 203.0.113.10")
        }
        // Spaces, a trailing comma and IPv6 are normalised or at least never an error.
        for value in ["  203.0.113.10  ", "x,  203.0.113.10 ,", "2001:db8::1", "[2001:db8::2]:443", ",", " ", "a,b,c,,,"] {
            let s = try await status(app, value)
            XCTAssertLessThan(s.code, 500, value)
        }
    }

    func testExtra_TrustedProxyWithoutHeaderSharesTheConnectionAddress() async throws {
        let app = try await proxied()
        defer { Task { try? await app.asyncShutdown() } }
        for _ in 0..<2 { let ok = try await status(app, nil); XCTAssertEqual(ok, .ok) }
        let s = try await status(app, nil)
        XCTAssertEqual(s, .tooManyRequests)
    }

    /// RFC 9110 5.3: several header lines of one field are one comma-separated list. A proxy that appends its
    /// entry as a NEW line must be read the same way, so the trusted (last) entry is the proxy's, not the client's.
    func testExtra_TrustedProxyReadsTheLastEntryAcrossRepeatedHeaderLines() async throws {
        let app = try await proxied()
        defer { Task { try? await app.asyncShutdown() } }
        func lines(_ values: [String]) -> HTTPHeaders {
            var h = HTTPHeaders()
            for v in values { h.add(name: "X-Forwarded-For", value: v) }
            return h
        }
        for _ in 0..<2 { _ = try await app.qaSend(.GET, "healthz", headers: lines(["203.0.113.20"])) }
        var limitedCount = 0
        for i in 0..<5 {
            let r = try await app.qaSend(.GET, "healthz", headers: lines(["198.51.100.\(i)", "203.0.113.20"]))
            if r.status == .tooManyRequests { limitedCount += 1 }
        }
        XCTAssertEqual(limitedCount, 5, "the client-written first line chose the identity; the proxy line (last) must decide")
    }

    func testExtra_LimitedResponseIsStillTheContractEnvelopeForEveryReadRoute() async throws {
        for _ in 0..<130 { _ = try await app.qaSend(.GET, "healthz") }
        for path in ["healthz", "v1/catalog", "privacy", "assets/images/none.png", "v1/unknown"] {
            let r = try await app.qaSend(.GET, path)
            XCTAssertEqual(r.status, .tooManyRequests, path)
            XCTAssertEqual(r.errorCode, "RATE_LIMITED", path)
        }
    }

    func testExtra_ParallelBurstNeverExceedsTheBudget() async throws {
        let small = try await CatalogApp.makeWithoutDatabase(CatalogApp.config(databaseURL: nil, readLimit: 50))
        defer { Task { try? await small.asyncShutdown() } }
        let app: Application = small
        let codes = try await withThrowingTaskGroup(of: UInt.self) { group in
            for _ in 0..<200 { group.addTask { try await app.qaSend(.GET, "healthz").status.code } }
            var all: [UInt] = []
            for try await c in group { all.append(c) }
            return all
        }
        XCTAssertEqual(codes.filter { $0 == 200 }.count, 50, "exactly the budget passes under concurrency")
        XCTAssertEqual(codes.filter { $0 == 429 }.count, 150)
    }
}
