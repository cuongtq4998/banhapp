import XCTest
@testable import App

/// Runs without PostgreSQL: the classification does not need a connection.
final class DatabaseErrorTranslationTests: XCTestCase {
    private struct UnreachableDatabase: Error {}

    func testAnUnknownShopStaysAnInternalErrorAndIsNotAnOutage() async {
        do {
            _ = try await translatingDatabaseErrors { throw CatalogRepositoryError.shopNotFound } as Int
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? CatalogRepositoryError, .shopNotFound)
            XCTAssertEqual(APIError.from(error).code, .internalError)
        }
    }

    func testAnUnclassifiedFailureIsAnOutage() async {
        do {
            _ = try await translatingDatabaseErrors { throw UnreachableDatabase() } as Int
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual((error as? APIError)?.code, .serviceUnavailable)
        }
    }
}
