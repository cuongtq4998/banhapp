import XCTest
import XCTVapor
@testable import AppUnderTest

/// Caching headers, conditional requests and unusual methods, parameters and paths of `GET /v1/catalog`.
final class CatalogCachingTests: CatalogTestBase {

    // MARK: Caching headers, ETag, 304 (TC-3, ADR-0011)

    func testTC3_Headers200() async throws {
        let reply = try await catalog()
        XCTAssertEqual(reply.status, .ok)
        XCTAssertEqual(reply.header("Cache-Control")?.lowercased(), "no-cache")
        let etag = try XCTUnwrap(reply.header("ETag"), "ETag missing")
        XCTAssertNotNil(etag.range(of: "^\"[0-9a-f]{32}\"$", options: .regularExpression), "api.md 4.1 (ADR-0017): strong tag, quoted 32 lowercase hex: \(etag)")
    }

    func testTC3_SameDataSameEtagAndConditionalRequestIs304WithEmptyBody() async throws {
        let first = try await catalog()
        let second = try await catalog()
        let etag = try XCTUnwrap(first.header("ETag"))
        XCTAssertEqual(second.header("ETag"), etag, "ETag must be deterministic for equal content")
        XCTAssertEqual(first.body, second.body)
        let conditional = try await catalog(["If-None-Match": etag])
        XCTAssertEqual(conditional.status, .notModified)
        XCTAssertEqual(conditional.body.count, 0)
        XCTAssertEqual(conditional.header("ETag"), etag, "RFC 9110 15.4.5: 304 repeats the ETag")
        XCTAssertEqual(conditional.header("Cache-Control"), "no-cache", "api.md 4.1: a 304 repeats Cache-Control")
        XCTAssertNotNil(conditional.header("X-Request-Id"))
        XCTAssertNil(conditional.header("Content-Type"), "api.md 4.1: a 304 does not repeat Content-Type")
    }

    func testExtra_EtagChangesWhenOnlyServerDateChanges() async throws {
        app.services.clock = FixedWallClock(instant: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-02T03:00:00Z")))
        let day1 = try await catalog()
        app.services.clock = FixedWallClock(instant: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-03T03:00:00Z")))
        let day2 = try await catalog(["If-None-Match": try XCTUnwrap(day1.header("ETag"))])
        XCTAssertEqual(day2.status, .ok, "server_date changed, so the old ETag must not give 304 (clients rely on server_date)")
        XCTAssertNotEqual(day2.header("ETag"), day1.header("ETag"))
    }

    // MARK: Adversarial conditional requests (extra)

    func testExtra_ConditionalRequestVariants() async throws {
        let first = try await catalog()
        let etag = try XCTUnwrap(first.header("ETag"))
        let bare = etag.hasPrefix("W/") ? String(etag.dropFirst(2)) : etag
        let inner = bare.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        let notModified: [(String, String)] = [
            ("strong form", bare),
            ("weak form of the same tag (weak comparison, RFC 9110 13.1.2)", "W/" + bare),
            ("list containing the tag", "\"other\", \(bare), \"another\""),
            ("list with extra spaces and tabs", "\"other\" ,\t\(bare)\t"),
            ("star matches any current representation", "*")
        ]
        for (label, value) in notModified {
            let r = try await catalog(["If-None-Match": value])
            XCTAssertEqual(r.status, .notModified, label)
        }
        let fullBody: [(String, String)] = [
            ("different tag", "\"0000\""),
            ("unquoted tag value", inner),
            ("empty header", ""),
            ("only whitespace", "   "),
            ("tag with trailing garbage", bare + "x"),
            ("truncated quote", "\"" + inner),
            ("lowercase weak marker is not a marker", "w/" + bare),
            ("comma only", ","),
            ("null byte text", "\"a\\0b\"")
        ]
        for (label, value) in fullBody {
            let r = try await catalog(["If-None-Match": value])
            XCTAssertEqual(r.status, .ok, label)
            XCTAssertEqual(r.body, first.body, label)
        }
    }

    func testExtra_LargeIfNoneMatchNeverCausesAServerError() async throws {
        let first = try await catalog()
        let etag = try XCTUnwrap(first.header("ETag"))
        for size in [1_000, 7_000, 100_000, 1_000_000] {
            let filler = (0..<(size / 10)).map { _ in "\"abcdefgh\"" }.joined(separator: ",")
            let r = try await catalog(["If-None-Match": filler])
            XCTAssertEqual(r.status, .ok, "size \(size)")
            let withMatch = try await catalog(["If-None-Match": filler + "," + etag])
            XCTAssertEqual(withMatch.status, .notModified, "size \(size), matching tag last")
        }
    }

    func testExtra_HeaderNameCaseAndRepeatedHeaderLines() async throws {
        let base = try await catalog()
        let etag = try XCTUnwrap(base.header("ETag"))
        var lower = HTTPHeaders()
        lower.add(name: "if-none-match", value: etag)
        let a = try await catalog(lower)
        XCTAssertEqual(a.status, .notModified)
        var twoLines = HTTPHeaders()
        twoLines.add(name: "If-None-Match", value: "\"nope\"")
        twoLines.add(name: "If-None-Match", value: etag)
        let b = try await catalog(twoLines)
        XCTAssertEqual(b.status, .notModified, "repeated header lines combine as a list (RFC 9110 5.3)")
    }

    func testExtra_IfModifiedSinceAloneDoesNotProduce304() async throws {
        let r = try await catalog(["If-Modified-Since": "Wed, 21 Oct 2037 07:28:00 GMT"])
        XCTAssertEqual(r.status, .ok, "no Last-Modified is promised; validators are ETag only")
    }

    // MARK: Other methods, parameters, paths (extra)

    /// api.md 4.1 (v1.6): HEAD is not part of the contract; an unrouted method answers 404 NOT_FOUND.
    func testExtra_HeadIsNotPartOfTheContract() async throws {
        let head = try await app.qaSend(.HEAD, Slice1.catalogPath)
        XCTAssertLessThan(head.status.code, 500)
        if head.status != .ok { XCTAssertEqual(head.status, .notFound) }
    }

    func testExtra_OtherMethodsAreTheDocumentedNotFoundEnvelope() async throws {
        for method in [HTTPMethod.POST, .PUT, .DELETE, .PATCH] {
            let r = try await app.qaSend(method, Slice1.catalogPath)
            XCTAssertEqual(r.status, .notFound, "\(method)")
            XCTAssertEqual(Slice1.envelopeProblems(r, code: "NOT_FOUND", messageKey: "ERR_SERVER"), [], "\(method)")
        }
    }

    func testExtra_UnknownQueryParametersAreHarmlessAndDoNotForkTheCache() async throws {
        // api.md 4.1 (v1.6): any query parameter is ignored; 200 with the same body and ETag, never 422 or 5xx.
        let base = try await catalog()
        for query in ["?x=1", "?slot_id=00000000-0000-4000-8000-000000000031", "?cakes=2", "?%00=%00", "?a=" + String(repeating: "z", count: 5000), "?deep=1", "?page=2&limit=1"] {
            let r = try await app.qaSend(.GET, Slice1.catalogPath + query)
            XCTAssertLessThan(r.status.code, 500, query)
            XCTAssertEqual(r.status, .ok, query)
            XCTAssertEqual(r.body, base.body, "query \(query) changed the data")
            XCTAssertEqual(r.header("ETag"), base.header("ETag"), query)
        }
    }

    func testExtra_PathVariantsNeverReachAnErrorState() async throws {
        for path in ["v1/catalog/", "V1/catalog", "v1/Catalog", "v1//catalog", "v1/catalog/extra", "v2/catalog", "catalog", "v1/catalog%00", "v1/catalog.json"] {
            let r = try await app.qaSend(.GET, path)
            XCTAssertLessThan(r.status.code, 500, path)
            if r.status != .ok { XCTAssertEqual(r.status, .notFound, path); XCTAssertEqual(r.errorCode, "NOT_FOUND", path) }
        }
    }

    func testExtra_AcceptHeaderVariantsStillGetJsonOrNotAcceptable() async throws {
        for accept in ["text/html", "*/*", "application/xml", "application/json;q=0", "garbage"] {
            let r = try await catalog(["Accept": accept])
            XCTAssertLessThan(r.status.code, 500, accept)
            if r.status == .ok { XCTAssertTrue(r.header("Content-Type")?.contains("json") ?? false, accept) }
        }
    }

    func testExtra_ParallelReadsAreConsistent() async throws {
        let reference = try await catalog()
        let app: Application = self.app
        let replies = try await withThrowingTaskGroup(of: Reply.self) { group in
            for _ in 0..<40 { group.addTask { try await app.qaSend(.GET, Slice1.catalogPath) } }
            var all: [Reply] = []
            for try await r in group { all.append(r) }
            return all
        }
        XCTAssertEqual(replies.count, 40)
        for r in replies {
            XCTAssertEqual(r.status, .ok)
            XCTAssertEqual(r.body, reference.body)
            XCTAssertEqual(r.header("ETag"), reference.header("ETag"))
        }
    }

}
