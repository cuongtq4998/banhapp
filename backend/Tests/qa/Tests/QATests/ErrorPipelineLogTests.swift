import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTVapor
import NIOConcurrencyHelpers
@testable import AppUnderTest

// MARK: - Access log and request ids

final class ErrorPipelineLogTests: ErrorPipelineBase {

    func testClientRequestIdIsIgnoredAndIdsAreUnique() async throws {
        let ids = NIOLockedValueBox(Set<String>())
        for _ in 0..<20 {
            try await app.test(.GET, "healthz", headers: ["X-Request-Id": "forged\nline"]) { res async throws in
                let id = try XCTUnwrap(res.headers.first(name: "X-Request-Id"))
                XCTAssertNotNil(UUID(uuidString: id))
                ids.withLockedValue { _ = $0.insert(id) }
            }
        }
        XCTAssertEqual(ids.withLockedValue { $0.count }, 20)
    }

    // ---- access log injection ----

    func testAccessLogNeverCarriesRawClientText() async throws {
        let hostile: [HTTPHeaders] = [
            ["X-Platform": "ios\r\nFORGED", "X-App-Version": "1.2.3 extra"],
            ["X-Platform": "IOS", "X-App-Version": "1.2.3\t"],
            ["X-Platform": "android", "X-App-Version": "123456.1.1"],
            ["X-Platform": "ios", "X-App-Version": "1.2.3.4"],
            ["X-Platform": "", "X-App-Version": ""],
            ["X-Platform": "iosandroid", "X-App-Version": "../../1.2.3"],
            ["X-Platform": "ios", "X-App-Version": "١.٢.٣"]
        ]
        for headers in hostile {
            try await app.test(.GET, "healthz?phone=0900000000&name=Nguyen", headers: headers) { _ async throws in }
        }
        try await app.test(.GET, "%0A%0Dforged%20line%20status=200") { _ async throws in }
        let lines = capture.lines.filter { $0.message == "request" }
        XCTAssertEqual(lines.count, hostile.count + 1, "exactly one access line per request")
        for line in lines {
            for (key, value) in line.metadata {
                let text = "\(value)"
                XCTAssertFalse(text.contains("\n") || text.contains("\r"), "\(key) holds a line break")
                XCTAssertFalse(text.contains("0900000000") || text.contains("Nguyen") || text.contains("forged"), "\(key) leaks client text")
            }
            XCTAssertTrue(["ios", "android", "-"].contains("\(line.metadata["platform"] ?? "")"))
        }
        XCTAssertEqual("\(lines.last?.metadata["route"] ?? "")", "-")
    }

    func testAccessLogCarriesErrorCodeStatusAndDuration() async throws {
        try await app.test(.GET, "qa/abort/429") { _ async throws in }
        let line = try XCTUnwrap(capture.lines.last { $0.message == "request" })
        XCTAssertEqual("\(line.metadata["error_code"] ?? "")", "RATE_LIMITED")
        XCTAssertEqual("\(line.metadata["status"] ?? "")", "429")
        XCTAssertNotNil(Int("\(line.metadata["duration_ms"] ?? "")"))
        XCTAssertEqual("\(line.metadata["route"] ?? "")", "/qa/abort/:code")
    }

    func testParallelRequestsKeepOneRequestIdPerLogLine() async throws {
        let app: Application = self.app
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<40 { group.addTask { try await app.test(.GET, "healthz") { _ async throws in } } }
            try await group.waitForAll()
        }
        let lines = capture.lines.filter { $0.message == "request" }
        XCTAssertEqual(lines.count, 40)
        let ids = lines.compactMap { "\($0.metadata["request-id"] ?? "")" }
        XCTAssertEqual(Set(ids).count, 40)
        XCTAssertTrue(ids.allSatisfy { UUID(uuidString: $0) != nil })
    }
}
