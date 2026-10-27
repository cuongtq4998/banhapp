import Foundation
import XCTest
import XCTVapor
import Fluent
import FluentSQL
@testable import AppUnderTest

/// Builds applications for the slice 1 tests. The working directory is the
/// backend folder, as when the server runs from source, so `assets/` resolves
/// (the QA package runs from `backend/Tests/qa`).
enum CatalogApp {
    static func config(
        databaseURL: String?, shopID: UUID? = Slice1.Seed.shopID, trustProxy: Bool = false,
        readLimit: Int = AppConfig.Default.rateLimitReadPerMinute,
        windowSeconds: TimeInterval = AppConfig.Default.rateLimitWindowSeconds,
        assetBaseURL: String = ""
    ) -> AppConfig {
        AppConfig(stage: .local, port: 8080, databaseURL: databaseURL, shopID: shopID, trustProxy: trustProxy,
                  rateLimitReadPerMinute: readLimit, publicAssetBaseURL: assetBaseURL, rateLimitWindowSeconds: windowSeconds)
    }

    private static func makeApplication() async throws -> Application {
        let app = try await Application.make(.testing)
        app.directory.workingDirectory = QAPaths.backend.path + "/"
        return app
    }

    /// Against the database named by DATABASE_MIGRATION_URL: schema migrated and
    /// the sample seed applied (both idempotent), the app reading through it.
    static func make(clock: (any WallClock)? = nil, assetBaseURL: String = "") async throws -> Application {
        guard let url = Slice1.databaseURL else {
            throw XCTSkip("\(Slice1.dbVariable) not set; catalog database tests skipped")
        }
        let app = try await makeApplication()
        do {
            try await configure(app, config: config(databaseURL: url, assetBaseURL: assetBaseURL))
            for file in try MigrationFiles.load(from: QAPaths.migrations) { app.migrations.add(file) }
            try await app.autoMigrate()
            let seed = try String(contentsOf: QAPaths.seed, encoding: .utf8)
            let sql = app.db as! any SQLDatabase
            for statement in SQLScriptSplitter.statements(in: seed) {
                try await sql.raw(SQLQueryString(statement)).run()
            }
            if let clock { app.services.clock = clock }
            return app
        } catch {
            try await app.asyncShutdown()
            throw error
        }
    }

    /// The migrated and seeded database, served for another SHOP_ID.
    static func makeWithShop(_ shopID: UUID) async throws -> Application {
        guard let url = Slice1.databaseURL else {
            throw XCTSkip("\(Slice1.dbVariable) not set; catalog database tests skipped")
        }
        let app = try await makeApplication()
        try await configure(app, config: config(databaseURL: url, shopID: shopID))
        return app
    }

    /// A database that cannot be reached (nothing listens on the port).
    static func makeUnreachable() async throws -> Application {
        let app = try await makeApplication()
        try await configure(app, config: config(databaseURL: "postgres://qa:qa@127.0.0.1:1/qa"))
        return app
    }

    /// No database at all (local run without DATABASE_URL).
    static func makeWithoutDatabase(_ config: AppConfig? = nil) async throws -> Application {
        let app = try await makeApplication()
        try await configure(app, config: config ?? Self.config(databaseURL: nil))
        return app
    }
}

extension QAPaths {
    /// Directories that may hold the static files of the slice (api.md 4.5 and
    /// 4.6 name `backend/assets/`; Vapor's default is `Public/`).
    static var assetRoots: [URL] {
        [backend.appendingPathComponent("assets"), backend.appendingPathComponent("Public")]
    }

    /// Finds a file by relative path under any asset root.
    static func assetFile(_ relative: String) -> URL? {
        for root in assetRoots {
            let candidate = root.appendingPathComponent(relative)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    /// Every `image_path` literal in the sample seed (so a new sample cake is checked too).
    static func seedImagePaths() throws -> [String] {
        let seed = try String(contentsOf: QAPaths.seed, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: "'((?:[A-Za-z0-9_./-]+)\\.(?:png|jpe?g|webp))'")
        let range = NSRange(seed.startIndex..., in: seed)
        return regex.matches(in: seed, range: range).compactMap { m in
            Range(m.range(at: 1), in: seed).map { String(seed[$0]) }
        }
    }
}
