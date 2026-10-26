import XCTest
@testable import App

final class MigrationFilesTests: XCTestCase {
    func testLoadsRealMigrationsInOrder() throws {
        let files = try MigrationFiles.load(from: TestPaths.migrations)
        XCTAssertEqual(files.first?.fileName, "0001_init.sql")
        XCTAssertEqual(files.map(\.fileName), files.map(\.fileName).sorted())
        XCTAssertTrue(files.allSatisfy { !$0.statements.isEmpty })
    }

    func testRejectsBadFileName() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("migrations-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "SELECT 1;".write(to: dir.appendingPathComponent("init.sql"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try MigrationFiles.load(from: dir.path))
    }

    func testMigrationNameIsFileName() {
        XCTAssertEqual(SQLFileMigration(fileName: "0002_x.sql", statements: []).name, "0002_x.sql")
    }
}
