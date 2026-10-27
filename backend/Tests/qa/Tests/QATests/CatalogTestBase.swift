import XCTest
import XCTVapor
import Fluent
import FluentSQL
@testable import AppUnderTest

/// Base of every `GET /v1/catalog` test class that talks to the database. Holds no test methods.
/// setUp restores the sample seed (when mutation is allowed) so a class never sees the leftovers of an
/// interrupted or earlier run; the mutating tests share one database and run one after the other.

class CatalogTestBase: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await CatalogApp.make()
        // Start from the seed even when an earlier run was interrupted halfway through a data change.
        if Slice1.mutationAllowed { try await restoreSample() }
    }

    override func tearDown() async throws {
        if let app { try await app.asyncShutdown() }
    }

    func catalog(_ headers: HTTPHeaders = [:]) async throws -> Reply {
        try await app.qaSend(.GET, Slice1.catalogPath, headers: headers)
    }

    func okCatalog() async throws -> (Reply, J) {
        let reply = try await catalog()
        XCTAssertEqual(reply.status, .ok, "GET /v1/catalog: \(reply.text.prefix(200))")
        return (reply, try XCTUnwrap(reply.json, "catalog body is not JSON"))
    }

    func execute(_ sql: String) async throws {
        try await (app.db as! any SQLDatabase).raw(SQLQueryString(sql)).run()
    }

    /// Puts every row a test in this file may have changed back to the sample seed, so a test never sees the
    /// leftovers of another one (the mutating tests share one database and run one after the other).
    func restoreSample() async throws {
        try await execute("UPDATE district SET is_active = true")
        try await execute("UPDATE delivery_slot SET is_active = true")
        try await execute("UPDATE product SET is_active = true")
        for (position, product) in Slice1.Seed.products.enumerated() {
            try await execute("UPDATE product SET sort_order = \(position + 1), price_vnd = \(product.3) WHERE id = '\(product.4)'")
        }
        try await execute("UPDATE shop_setting SET min_qty = \(Slice1.Seed.settings["min_qty"]!), lead_days = \(Slice1.Seed.settings["lead_days"]!)")
    }
}
