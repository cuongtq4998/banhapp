import XCTest
@testable import App

final class SQLScriptSplitterTests: XCTestCase {
    private static func withoutLeadingComments(_ statement: String) -> String {
        statement.split(separator: "\n", omittingEmptySubsequences: false)
            .drop(while: { $0.hasPrefix("--") || $0.allSatisfy(\.isWhitespace) })
            .joined(separator: "\n")
    }

    func testSplitsPlainStatements() {
        XCTAssertEqual(SQLScriptSplitter.statements(in: "SELECT 1; SELECT 2;"), ["SELECT 1", "SELECT 2"])
    }

    func testKeepsSemicolonInsideQuotedString() {
        let sql = "INSERT INTO t VALUES ('a;b', 'it''s; fine'); SELECT 1"
        XCTAssertEqual(SQLScriptSplitter.statements(in: sql), [
            "INSERT INTO t VALUES ('a;b', 'it''s; fine')", "SELECT 1"
        ])
    }

    func testKeepsDollarQuotedBodyWhole() {
        let sql = """
        CREATE FUNCTION f() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
            RETURN NEW;
        END;
        $$;
        CREATE TRIGGER t BEFORE UPDATE ON x FOR EACH ROW EXECUTE FUNCTION f();
        """
        let parts = SQLScriptSplitter.statements(in: sql)
        XCTAssertEqual(parts.count, 2)
        XCTAssertTrue(parts[0].hasSuffix("$$"))
        XCTAssertTrue(parts[0].contains("RETURN NEW;"))
    }

    func testKeepsTaggedDollarQuote() {
        let sql = "DO $body$ BEGIN PERFORM 1; END; $body$; SELECT 2"
        XCTAssertEqual(SQLScriptSplitter.statements(in: sql).count, 2)
    }

    func testIgnoresSemicolonInComments() {
        let sql = "-- one; two\nSELECT 1; /* a; b */ SELECT 2"
        XCTAssertEqual(SQLScriptSplitter.statements(in: sql).count, 2)
    }

    func testKeepsSemicolonAndBackslashQuoteInsideEscapeString() {
        let sql = #"SELECT E'a\';b', e'x\\'; SELECT 2"#
        XCTAssertEqual(SQLScriptSplitter.statements(in: sql), [#"SELECT E'a\';b', e'x\\'"#, "SELECT 2"])
    }

    func testBackslashIsLiteralInStandardStrings() {
        // Standard strings do not treat the backslash as an escape.
        XCTAssertEqual(SQLScriptSplitter.statements(in: #"SELECT 'a\'; SELECT 2"#), [#"SELECT 'a\'"#, "SELECT 2"])
    }

    func testELetterEndingAWordDoesNotStartAnEscapeString() {
        // `name'..'` is not valid SQL, but `value` followed by a string must not be read as E'..'.
        XCTAssertEqual(SQLScriptSplitter.statements(in: #"SELECT date'x\'; SELECT 2"#).count, 2)
    }

    func testKeepsSemicolonInsideQuotedIdentifier() {
        let sql = #"CREATE TABLE "a;b" ("c""d;" int); SELECT 1"#
        XCTAssertEqual(SQLScriptSplitter.statements(in: sql), [#"CREATE TABLE "a;b" ("c""d;" int)"#, "SELECT 1"])
    }

    func testNestedBlockCommentsAreOneComment() {
        let sql = "SELECT 1 /* a; /* b; */ c; */; SELECT 2"
        XCTAssertEqual(SQLScriptSplitter.statements(in: sql), ["SELECT 1 /* a; /* b; */ c; */", "SELECT 2"])
        XCTAssertEqual(SQLScriptSplitter.statements(in: "/* x /* y */ ; */;"), [])
    }

    func testQuoteInsideCommentOrIdentifierDoesNotOpenAString() {
        let sql = "-- it's\nSELECT \"it's\"; /* don't */ SELECT 2"
        XCTAssertEqual(SQLScriptSplitter.statements(in: sql).count, 2)
    }

    func testDropsCommentOnlyAndEmptyChunks() {
        XCTAssertEqual(SQLScriptSplitter.statements(in: "-- nothing\n;;\n/* x */;"), [])
    }

    func testRealInitMigrationYieldsOnlyDDL() throws {
        let script = try String(
            contentsOfFile: TestPaths.migrations + "/0001_init.sql", encoding: .utf8)
        let parts = SQLScriptSplitter.statements(in: script)
        XCTAssertGreaterThan(parts.count, 20)
        for part in parts {
            // A bad split would leave fragments such as "END" or "RETURN NEW".
            let head = part.drop(while: { $0 == "-" || $0 == " " || $0 == "\n" || !$0.isUppercase }).prefix(12)
            XCTAssertTrue(
                part.contains("CREATE ") , "Unexpected statement start: \(head)")
        }
        let tables = parts.filter { Self.withoutLeadingComments($0).hasPrefix("CREATE TABLE") }.count
        XCTAssertEqual(tables, 9)
        XCTAssertEqual(parts.filter { $0.contains("CREATE TRIGGER") }.count, 4)
    }

    func testSeedYieldsOnlyInserts() throws {
        let script = try String(contentsOf: TestPaths.seed, encoding: .utf8)
        let parts = SQLScriptSplitter.statements(in: script)
        XCTAssertFalse(parts.isEmpty)
        XCTAssertTrue(parts.allSatisfy { $0.contains("INSERT INTO") })
        XCTAssertFalse(parts.contains { Self.withoutLeadingComments($0).contains("is_sample = false") })
        // Every sample statement marks its rows as sample (AC-29).
        XCTAssertTrue(parts.allSatisfy { $0.contains("true") })
    }
}
