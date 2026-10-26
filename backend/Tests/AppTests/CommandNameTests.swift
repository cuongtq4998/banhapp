import XCTest
import Vapor
@testable import App

final class CommandNameTests: XCTestCase {
    private let program = "/usr/bin/App"

    func testFindsTheCommandInEveryArgumentOrder() {
        let cases: [[String]] = [
            ["migrate"],
            ["migrate", "--yes"],
            ["--yes", "migrate"],
            ["--yes", "--verbose", "migrate"],
        ]
        for arguments in cases {
            XCTAssertEqual(requestedCommand(in: [program] + arguments), "migrate", "\(arguments)")
        }
    }

    func testNoCommandMeansServe() {
        XCTAssertNil(requestedCommand(in: [program]))
        XCTAssertNil(requestedCommand(in: [program, "--yes"]))
        XCTAssertEqual(requestedCommand(in: [program, "serve", "--port", "8080"]), "serve")
    }

    /// Vapor removes `--env` and its value before the entrypoint looks, so the
    /// whole path from the raw command line is checked, not only the helper.
    func testDetectedEnvironmentKeepsTheCommandWhateverTheOptionOrder() throws {
        for arguments in [
            [program, "--env", "staging", "migrate", "--yes"],
            [program, "migrate", "--env", "staging", "--yes"],
            [program, "--yes", "-e", "staging", "migrate"],
        ] {
            let env = try Environment.detect(arguments: arguments)
            XCTAssertEqual(env.name, "staging")
            XCTAssertEqual(requestedCommand(in: env.arguments), migrateCommandName, "\(arguments)")
        }
    }
}
