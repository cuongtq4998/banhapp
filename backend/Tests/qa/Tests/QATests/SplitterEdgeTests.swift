import XCTest
@testable import AppUnderTest

/// Extra cases for the SQL script splitter (slice 0, migration runner).
final class SplitterEdgeTests: XCTestCase {
    private func split(_ s: String) -> [String] { SQLScriptSplitter.statements(in: s) }

    func testEmptyAndWhitespaceInput() {
        XCTAssertEqual(split(""), [])
        XCTAssertEqual(split("  \n\t "), [])
        XCTAssertEqual(split(";"), [])
    }

    func testLastStatementWithoutSemicolonIsKept() {
        XCTAssertEqual(split("SELECT 1; SELECT 2"), ["SELECT 1", "SELECT 2"])
    }

    func testCrLfLineEndings() {
        XCTAssertEqual(split("SELECT 1;\r\nSELECT 2;\r\n").count, 2)
    }

    func testCommentMarkersInsideStringAreText() {
        let parts = split("SELECT 'a--b;c', '/* x;'; SELECT 2")
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts[0], "SELECT 'a--b;c', '/* x;'")
    }

    func testDollarMarkersInsideStringAreText() {
        XCTAssertEqual(split("SELECT '$$'; SELECT 2").count, 2)
    }

    func testPositionalParametersAreNotDollarQuotes() {
        XCTAssertEqual(split("SELECT $1; SELECT $2").count, 2)
    }

    func testQuotesAndSemicolonsInsideDollarBody() {
        let parts = split("DO $$ BEGIN RAISE NOTICE 'it''s; ok'; END $$; SELECT 1")
        XCTAssertEqual(parts.count, 2)
    }

    func testDifferentTagInsideDollarBodyDoesNotClose() {
        let parts = split("DO $a$ BEGIN PERFORM $b$x;y$b$; END $a$; SELECT 1")
        XCTAssertEqual(parts.count, 2)
    }

    func testLineCommentAtEndWithoutNewline() {
        XCTAssertEqual(split("SELECT 1; -- done"), ["SELECT 1"])
    }

    func testUnterminatedConstructsDoNotHangOrCrash() {
        _ = split("SELECT 'abc; SELECT 2")
        _ = split("DO $$ BEGIN")
        _ = split("/* never closed ; SELECT 1")
        _ = split("SELECT $")
        _ = split("SELECT $a")
    }

    func testVietnameseTextSurvives() {
        let parts = split("INSERT INTO t VALUES ('Bánh đậu xanh; nhân mỡ'); SELECT 1")
        XCTAssertEqual(parts.first, "INSERT INTO t VALUES ('Bánh đậu xanh; nhân mỡ')")
    }

    func testLargeScriptIsFast() {
        let script = String(repeating: "INSERT INTO t VALUES (1, 'x;y');\n", count: 20_000)
        let started = ContinuousClock.now
        XCTAssertEqual(split(script).count, 20_000)
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(5))
    }

    // ---- D-4 (fixed in round 2): valid PostgreSQL the old scanner cut wrongly. ----

    func testEscapeStringWithBackslashQuote() {
        // E'...\'...' keeps the string open after the backslash-quote.
        XCTAssertEqual(split("SELECT E'it\\'s; fine'; SELECT 2"), ["SELECT E'it\\'s; fine'", "SELECT 2"])
    }

    func testQuotedIdentifierWithSemicolon() {
        XCTAssertEqual(split("CREATE TABLE \"a;b\" (x int); SELECT 2"), ["CREATE TABLE \"a;b\" (x int)", "SELECT 2"])
    }

    func testNestedBlockComment() {
        XCTAssertEqual(split("/* a /* b */ ; c */ SELECT 1; SELECT 2"), ["/* a /* b */ ; c */ SELECT 1", "SELECT 2"])
    }
}
