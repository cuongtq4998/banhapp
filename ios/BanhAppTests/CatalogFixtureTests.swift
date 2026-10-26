import BanhContracts
import XCTest
@testable import BanhApp

final class CatalogFixtureTests: XCTestCase {
    /// The 304 revalidation exchange (headers only, no catalog body).
    private struct Exchange: Decodable {
        let status: Int
        let requestHeaders: [String: String]
        let responseHeaders: [String: String]

        private enum CodingKeys: String, CodingKey {
            case status
            case requestHeaders = "request_headers"
            case responseHeaders = "response_headers"
        }
    }

    private func isExchange(_ data: Data) throws -> Bool {
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return object["status"] != nil
    }

    /// Every `catalog-*.json` is either a catalog or the 304 exchange; the two are told apart by
    /// content (a `status` key), so a new fixture needs no change here.
    func testEveryCatalogFixtureDecodesAsItsKind() throws {
        let names = try Fixtures.names(withPrefix: "catalog-")
        XCTAssertTrue(names.contains("catalog-ok.json") && names.contains("catalog-empty.json") && names.contains("catalog-not-modified.json"))
        for name in names {
            let data = try Fixtures.data(name)
            if try isExchange(data) {
                let exchange = try JSONDecoder().decode(Exchange.self, from: data)
                XCTAssertEqual(exchange.status, 304, name)
                XCTAssertEqual(exchange.requestHeaders["If-None-Match"], exchange.responseHeaders["ETag"], name)
            } else {
                XCTAssertNoThrow(try JSONDecoder().decode(CatalogResponse.self, from: data), name)
            }
        }
    }

    func testTheNotModifiedExchangeDrivesTheClientToUseTheCache() async throws {
        let exchange = try Fixtures.decode(Exchange.self, from: "catalog-not-modified.json")
        let etag = try XCTUnwrap(exchange.requestHeaders["If-None-Match"])
        XCTAssertTrue(etag.hasPrefix("\"") && etag.hasSuffix("\""), "the validator is strong and quoted")
        let transport = StubHTTPTransport([.response(status: exchange.status, headers: exchange.responseHeaders)])
        let api = HTTPCatalogAPI(client: APIClient(
            baseURL: URL(string: "http://localhost:8080")!, appVersion: "1", transport: transport
        ))

        let result = try await api.fetchCatalog(etag: etag)

        XCTAssertEqual(result, .notModified)
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "If-None-Match"), etag)
    }

    func testOkFixtureHasTheFourCakesWithVersionedImages() throws {
        let catalog = try CatalogTestData.okCatalog()
        XCTAssertEqual(catalog.products.count, 4)
        XCTAssertTrue(catalog.products.allSatisfy { $0.imageURL.contains("?v=") })
        XCTAssertEqual(catalog.settings.noteMaxLength, 200)
    }

    func testEmptyFixtureIsTheOnlyFailedListCase() throws {
        let empty = try Fixtures.decode(CatalogResponse.self, from: "catalog-empty.json")
        XCTAssertTrue(empty.products.isEmpty)
    }

    func testNoCustomerVisibleCatalogTextCarriesASampleMarker() throws {
        let catalog = try CatalogTestData.okCatalog()
        let visible = [catalog.shop.name, catalog.shop.greeting]
            + catalog.products.flatMap { [$0.name, $0.description] }
            + catalog.districts.map(\.name)
        for text in visible {
            for word in ["mẫu", "sample", "test", "demo", "fake"] {
                XCTAssertFalse(text.lowercased().contains(word), "\"\(text)\" contains \"\(word)\"")
            }
        }
    }
}
