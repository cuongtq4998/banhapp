import XCTest
@testable import AppUnderTest

// MARK: - Splitter, second pass

final class SplitterReviewTests: XCTestCase {
    private func split(_ s: String) -> [String] { SQLScriptSplitter.statements(in: s) }

    func testStandardStringBackslashIsLiteral() {
        XCTAssertEqual(split("SELECT 'a\\'; SELECT 2"), ["SELECT 'a\\'", "SELECT 2"])
    }

    func testEscapedBackslashBeforeClosingQuoteInEscapeString() {
        XCTAssertEqual(split("SELECT E'\\\\'; SELECT 2"), ["SELECT E'\\\\'", "SELECT 2"])
        XCTAssertEqual(split("SELECT e'x\\'y;z'; SELECT 2").count, 2)
    }

    func testIdentifierEndingInEIsNotAnEscapeString() {
        // `name'..'` is not valid SQL, but `somee` followed by a string must not turn on backslash escapes
        XCTAssertEqual(split("SELECT tablee, 'a\\'; SELECT 2").count, 2)
    }

    func testDoubledQuoteInsideIdentifier() {
        XCTAssertEqual(split("CREATE TABLE \"a\"\"b;c\" (x int); SELECT 2").count, 2)
    }

    func testDollarTagVariants() {
        XCTAssertEqual(split("DO $a1$ BEGIN PERFORM 1; END $a1$; SELECT 2").count, 2)
        XCTAssertEqual(split("DO $é$ BEGIN PERFORM 1; END $é$; SELECT 2").count, 2)
        XCTAssertEqual(split("DO $x$ a $$ ; $$ b $x$; SELECT 2").count, 2)
        XCTAssertEqual(split("DO $_t$ a ; $_t$; SELECT 2").count, 2)
    }

    func testCommentsInsideDollarBodyAreBodyText() {
        XCTAssertEqual(split("DO $$ -- it's a trap; $$ ;\nSELECT 2").count, 1 + 1)
    }

    func testDefectDollarSignInsideAnIdentifierIsNotAQuote() {
        // PostgreSQL allows `$` inside an identifier: `a$b$c` is one name.
        XCTAssertEqual(split("SELECT a$b$c; SELECT 2"), ["SELECT a$b$c", "SELECT 2"])
    }

    func testStatementsKeepInnerComments() {
        XCTAssertEqual(split("SELECT 1 /* a;b */ + 2; -- x;y\nSELECT 3"), ["SELECT 1 /* a;b */ + 2", "-- x;y\nSELECT 3"])
    }

    func testOnlyCommentsAndSemicolons() {
        XCTAssertEqual(split("-- a\n/* b */;;; /* c */ ;"), [])
    }

    func testSeparatorWithoutSpacesAndManySemicolons() {
        XCTAssertEqual(split("SELECT 1;SELECT 2;;SELECT 3;"), ["SELECT 1", "SELECT 2", "SELECT 3"])
    }

    func testByteOrderMarkAndNul() {
        _ = split("\u{FEFF}SELECT 1; SELECT 2")
        _ = split("SELECT 1;\u{0}SELECT 2")
    }

    func testRealMigrationFilesSplitIntoWholeStatements() throws {
        let files = try MigrationFiles.load(from: QAPaths.migrations)
        XCTAssertFalse(files.isEmpty)
        for file in files {
            XCTAssertFalse(file.statements.isEmpty, file.fileName)
            for statement in file.statements {
                XCTAssertFalse(statement.hasSuffix(";") && !statement.uppercased().contains("$$") && statement.hasSuffix(";;"), file.fileName)
                // Quotes and dollar markers must be balanced in every piece.
                XCTAssertEqual(statement.filter { $0 == "'" }.count % 2, 0, "\(file.fileName): unbalanced quotes in a statement")
                XCTAssertEqual(statement.components(separatedBy: "$$").count % 2, 1, "\(file.fileName): unbalanced $$")
            }
        }
    }

    func testBadMigrationFileNamesAreRejected() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("qa-mig-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for name in ["1_init.sql", "0001_Init.sql", "0001-init.sql", "0001_init.SQL.sql", "00001_a.sql"] {
            let path = dir.appendingPathComponent(name)
            try "SELECT 1;".write(to: path, atomically: true, encoding: .utf8)
            XCTAssertThrowsError(try MigrationFiles.load(from: dir.path + "/"), name)
            try FileManager.default.removeItem(at: path)
        }
        try "SELECT 1;".write(to: dir.appendingPathComponent("0002_b.sql"), atomically: true, encoding: .utf8)
        try "SELECT 2;".write(to: dir.appendingPathComponent("0001_a.sql"), atomically: true, encoding: .utf8)
        try "ignored".write(to: dir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        XCTAssertEqual(try MigrationFiles.load(from: dir.path).map(\.fileName), ["0001_a.sql", "0002_b.sql"])
    }

    func testMissingMigrationDirectoryThrows() {
        XCTAssertThrowsError(try MigrationFiles.load(from: "/nonexistent-qa-dir/"))
    }
}
