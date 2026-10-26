import XCTest
@testable import AppUnderTest

/// Static checks of repository layout, container build inputs, workflows and
/// secret hygiene (slice 0, ADR-0004).
final class RepositoryLayoutTests: XCTestCase {
    private func exists(_ relative: String) -> Bool {
        FileManager.default.fileExists(atPath: QAPaths.repo.appendingPathComponent(relative).path)
    }

    func testMonorepoComponentsExist() {
        for path in ["backend/Package.swift", "backend/db/migrations/0001_init.sql", "backend/db/seed/sample.sql",
                     "backend/.env.example", "contracts/fixtures/healthz-ok.json", "contracts/swift/Package.swift",
                     "ios/BanhApp.xcodeproj", "android/settings.gradle.kts", ".github/workflows/backend.yml",
                     ".github/workflows/ios.yml", ".github/workflows/android.yml"] {
            XCTAssertTrue(exists(path), path)
        }
    }

    func testMigrationNumberingHasNoGapsOrDuplicates() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: QAPaths.migrations)
            .filter { $0.hasSuffix(".sql") }.sorted()
        let numbers = names.compactMap { Int($0.prefix(4)) }
        XCTAssertEqual(numbers, Array(1...max(1, names.count)))
    }

    func testMigrationsAreForwardOnlyAndFreeOfDestructiveStatements() throws {
        let sql = try String(contentsOf: URL(fileURLWithPath: QAPaths.migrations + "/0001_init.sql"), encoding: .utf8)
        XCTAssertFalse(sql.uppercased().contains("DROP "))
        XCTAssertFalse(sql.uppercased().contains("TRUNCATE"))
        XCTAssertFalse(sql.contains("IF NOT EXISTS"), "re-run safety comes from the migration ledger, not from masking errors")
    }

    func testSeedNeverDeletesOrUpdates() throws {
        let sql = try String(contentsOf: QAPaths.seed, encoding: .utf8).uppercased()
        for word in ["DELETE ", "UPDATE ", "DROP ", "TRUNCATE"] { XCTAssertFalse(sql.contains(word), word) }
    }

    func testSeedHasNoSampleMarkerInVisibleText() throws {
        // AC-29: the values the app shows must not say sample, demo or test.
        let sql = try String(contentsOf: QAPaths.seed, encoding: .utf8)
        let values = sql.split(separator: "\n").filter { !$0.hasPrefix("--") }.joined(separator: "\n").lowercased()
        let stripped = values.replacingOccurrences(of: "is_sample", with: "")
        for word in ["demo", "sample", "test", "mẫu", "payment"] { XCTAssertFalse(stripped.contains(word), word) }
    }

    /// D-1: every path Package.swift declares must reach the image build
    /// context, otherwise `swift package resolve` fails inside the image.
    func testDockerfileCopiesEveryTargetPathOfPackageSwift() throws {
        let manifest = try QAPaths.text("backend/Package.swift")
        let dockerfile = try QAPaths.text("backend/Dockerfile")
        let paths = manifest.components(separatedBy: "path: \"").dropFirst()
            .compactMap { $0.split(separator: "\"").first.map(String.init) }
            .filter { !$0.hasPrefix("..") }
        XCTAssertFalse(paths.isEmpty)
        for path in paths {
            let top = String(path.split(separator: "/").first ?? "")
            let copied = dockerfile.contains("COPY backend/\(top) ") || dockerfile.contains("COPY backend/\(top)/ ")
            XCTAssertTrue(copied, "\(path) is declared in Package.swift but not copied by backend/Dockerfile")
        }
    }

    func testEnvExampleCoversEveryVariableWorkflowsAndComposeUse() throws {
        let example = try QAPaths.text("backend/.env.example")
        for name in ["APP_ENV", "PORT", "DATABASE_URL", "DATABASE_MIGRATION_URL", "DATABASE_POOL_MAX"] {
            XCTAssertTrue(example.contains("\(name)="), name)
        }
        for line in example.split(separator: "\n") where !line.hasPrefix("#") && line.contains("=") {
            XCTAssertTrue(line.hasSuffix("="), ".env.example must hold names only: \(line.prefix(20))")
        }
    }

    func testWorkflowsDeclareLeastPrivilegeAndNoPullRequestTarget() throws {
        for file in ["backend", "ios", "android"] {
            let yml = try QAPaths.text(".github/workflows/\(file).yml")
            XCTAssertTrue(yml.contains("permissions:\n  contents: read"), file)
            XCTAssertFalse(yml.contains("pull_request_target"), file)
        }
    }

    func testSecretsAreOnlyReferencedByMainOnlyJobs() throws {
        let yml = try QAPaths.text(".github/workflows/backend.yml")
        let jobs = yml.components(separatedBy: "\n  deploy-staging:")
        XCTAssertEqual(jobs.count, 2)
        // GITHUB_TOKEN login is allowed in the image job but only for push events.
        XCTAssertFalse(jobs[0].replacingOccurrences(of: "secrets.GITHUB_TOKEN", with: "").contains("secrets."))
        XCTAssertTrue(jobs[1].contains("if: github.event_name == 'push'"))
    }

    func testNoCredentialLookingValuesCommitted() throws {
        let allowed = ["banh_local_only", "ci-job-only", "placeholder", "127.0.0.1", "localhost", "${"]
        let patterns = [#"postgres(ql)?://[^\s:/@]+:[^\s@]+@"#, "AKIA[0-9A-Z]{16}", "-----BEGIN [A-Z ]*PRIVATE KEY", "ghp_[A-Za-z0-9]{20,}"]
        let skip: Set<String> = [".build", ".git", "node_modules", "DerivedData", ".gradle", "build", ".swiftpm", "Pods", "qa"]
        var offenders: [String] = []
        let en = FileManager.default.enumerator(at: QAPaths.repo, includingPropertiesForKeys: [.isRegularFileKey])!
        for case let url as URL in en {
            if url.pathComponents.contains(where: skip.contains) { continue }
            if url.pathComponents.contains("worktrees") { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8), text.count < 2_000_000 else { continue }
            for pattern in patterns {
                for match in text.ranges(ofRegex: pattern) {
                    let line = text[text.lineRange(for: match)]
                    if !allowed.contains(where: { line.contains($0) }) { offenders.append(url.lastPathComponent) }
                }
            }
        }
        XCTAssertEqual(offenders, [])
    }
}

private extension String {
    func ranges(ofRegex pattern: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var start = startIndex
        while let r = range(of: pattern, options: .regularExpression, range: start..<endIndex) {
            result.append(r); start = r.upperBound
        }
        return result
    }
}
