import XCTVapor
import Logging
import BanhContracts
@testable import App

final class ErrorHandlingTests: ErrorHandlingTestCase {
    func testEveryNotFoundIsNoStore() async throws {
        app.get("raises-not-found") { _ -> String in throw Abort(.notFound) }
        for path in ["nope", "raises-not-found"] {
            try await app.test(.GET, path) { res async throws in
                XCTAssertEqual(res.status, .notFound, path)
                XCTAssertEqual(res.headers.first(name: .cacheControl), "no-store", path)
            }
        }
    }

    func testUnknownPathReturnsContractBody() async throws {
        try await app.test(.GET, "nope") { res async throws in
            XCTAssertEqual(res.status, .notFound)
            let body = try res.content.decode(APIErrorResponse.self)
            XCTAssertEqual(body.error, try self.fixture("error-not-found.json").error)
            XCTAssertEqual(res.headers.first(name: RequestIDLog.headerName), body.requestID)
            XCTAssertNotNil(UUID(uuidString: body.requestID))
        }
    }

    func testWrongMethodReturnsContractBody() async throws {
        try await app.test(.POST, "healthz") { res async throws in
            // Vapor answers an unmatched method on a known path with 404;
            // either way the body must be the contract envelope.
            XCTAssertTrue([.notFound, .methodNotAllowed].contains(res.status))
            XCTAssertNoThrow(try res.content.decode(APIErrorResponse.self))
        }
    }

    func testAPIErrorKeepsItsCodeStatusAndKey() async throws {
        try await app.test(.GET, "raises-api-error") { res async throws in
            XCTAssertEqual(res.status, .conflict)
            XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error, try self.fixture("error-date-capacity.json").error)
        }
    }

    func testUnexpectedErrorIsInternalErrorWithoutDetail() async throws {
        try await app.test(.GET, "raises-unexpected") { res async throws in
            XCTAssertEqual(res.status, .internalServerError)
            let body = try res.content.decode(APIErrorResponse.self)
            XCTAssertEqual(body.error.code, APIErrorCode.internalError.rawValue)
            XCTAssertEqual(body.error.details, [:])
            XCTAssertFalse(res.body.string.contains("DatabaseProbeError"))
        }
    }

    func testRequestIDIsGeneratedNotTrustedFromClient() async throws {
        var headers = HTTPHeaders()
        headers.add(name: RequestIDLog.headerName, value: "attacker\ninjected")
        try await app.test(.GET, "healthz", headers: headers) { res async throws in
            let id = try XCTUnwrap(res.headers.first(name: RequestIDLog.headerName))
            XCTAssertNotNil(UUID(uuidString: id))
        }
    }

    func testEveryCodeHasAConsistentStatusAndKey() {
        for code in APIErrorCode.allCases {
            XCTAssertFalse(code.messageKey.isEmpty)
            XCTAssertTrue((400...599).contains(Int(code.status.code)), code.rawValue)
        }
        XCTAssertEqual(APIErrorCode.dateCapacity.status, .conflict)
        XCTAssertEqual(APIErrorCode.minQty.status, .unprocessableEntity)
        XCTAssertEqual(APIErrorCode.priceChanged.messageKey, "MSG_PRICE_CHANGED")
        XCTAssertEqual(APIErrorCode.rateLimited.messageKey, "ERR_RATE_LIMITED")
        XCTAssertEqual(APIErrorCode.internalError.messageKey, APIErrorCode.genericMessageKey)
    }

    func testAbortMapping() {
        XCTAssertEqual(APIError.from(Abort(.payloadTooLarge)).code, .payloadTooLarge)
        XCTAssertEqual(APIError.from(Abort(.unprocessableEntity)).code, .validationFailed)
        XCTAssertEqual(APIError.from(Abort(.badGateway)).code, .internalError)
        XCTAssertEqual(APIError.from(DatabaseProbeError()).code, .internalError)
    }
}
