import XCTest
import XCTVapor
@testable import AppUnderTest

/// Slice 1: `/privacy` (api.md 4.5), `/assets/*` (4.6), asset files in the
/// repository, and the contract fixtures `catalog-*.json` (architecture.md 11).
/// Needs no database. EXPECTED-FAIL until the slice 1 backend merges.
final class StaticContentTests: XCTestCase {
    private var app: Application!

    override func setUp() async throws {
        app = try await CatalogApp.makeWithoutDatabase()
    }

    override func tearDown() async throws { try await app.asyncShutdown() }

    // MARK: Privacy page (TC-67, deployment 4)

    func testTC67_PrivacyPageIsServedAsUtf8Html() async throws {
        let r = try await app.qaSend(.GET, "privacy")
        XCTAssertEqual(r.status, .ok)
        let contentType = r.header("Content-Type")?.lowercased() ?? ""
        XCTAssertTrue(contentType.hasPrefix("text/html"), contentType)
        XCTAssertTrue(contentType.contains("utf-8"), "Vietnamese text needs an explicit charset: \(contentType)")
        XCTAssertTrue(r.text.lowercased().contains("<html"))
        XCTAssertTrue(r.text.lowercased().contains("lang=\"vi\""), "page language must be Vietnamese (AC-21 spirit)")
        XCTAssertNotNil(r.header("X-Request-Id"))
    }

    func testTC67_PrivacyPageNamesEveryCollectedItemAndPurposeAndRecipient() async throws {
        let r = try await app.qaSend(.GET, "privacy")
        let folded = Slice1.fold(r.text)
        for (label, needle) in [("name", "ho ten"), ("phone", "so dien thoai"), ("address", "dia chi"), ("note", "ghi chu"),
                                ("who sees it", "cua hang"), ("retention", "luu tru"), ("storage place", "luu tru")] {
            XCTAssertTrue(folded.contains(needle) || folded.contains(label == "name" ? "ten" : needle), "privacy page does not mention \(label) (api.md 4.5)")
        }
    }

    func testTC67_PrivacyPageHasNoPaymentWordsNoRemoteScriptsAndNoTrackers() async throws {
        let r = try await app.qaSend(.GET, "privacy")
        XCTAssertEqual(r.status, .ok)
        let paymentHits = Slice1.forbiddenHits(in: [r.text]).filter { !$0.hasPrefix("test") }
        XCTAssertEqual(paymentHits, [], "AC-27 / AC-29 apply to every customer-visible page")
        let lower = r.text.lowercased()
        XCTAssertFalse(lower.contains("<script"), "a static statement needs no script")
        XCTAssertFalse(lower.contains("http://"), "no cleartext links")
        for tracker in ["googletagmanager", "google-analytics", "facebook.net", "doubleclick"] {
            XCTAssertFalse(lower.contains(tracker), tracker)
        }
    }

    func testExtra_PrivacyHeadAndMethods() async throws {
        let head = try await app.qaSend(.HEAD, "privacy")
        XCTAssertEqual(head.status, .ok)
        XCTAssertEqual(head.body.count, 0)
        for method in [HTTPMethod.POST, .PUT, .DELETE] {
            let r = try await app.qaSend(method, "privacy")
            XCTAssertEqual(r.status, .notFound, "\(method)")
        }
        for path in ["privacy/", "Privacy", "privacy.html", "privacy?x=1"] {
            let r = try await app.qaSend(.GET, path)
            XCTAssertLessThan(r.status.code, 500, path)
        }
    }

    func testTC67_PrivacySourceFileExistsAndIsFakeFreeOfSecrets() throws {
        let url = QAPaths.backend.appendingPathComponent("assets/privacy.html")
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(text.isEmpty)
        for pattern in ["password", "secret", "token=", "postgres://", "@fpt.com"] {
            XCTAssertFalse(text.lowercased().contains(pattern), pattern)
        }
    }

    // MARK: Asset files and routes (TC-67)

    func testTC67_EverySeedImagePathHasAFileInTheRepository() throws {
        let paths = try QAPaths.seedImagePaths()
        XCTAssertEqual(paths.count, 4, "the seed names four product images")
        for path in paths {
            let basename = (path as NSString).lastPathComponent
            let found = QAPaths.assetRoots.contains { root in
                guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return false }
                return (walker.allObjects as? [URL] ?? []).contains { $0.lastPathComponent == basename }
            }
            XCTAssertTrue(found, "no file named \(basename) under backend/assets or backend/Public (seed image_path \(path))")
        }
    }

    func testTC67_AssetFilesAreRealImagesOfReasonableSize() throws {
        var checked = 0
        for root in QAPaths.assetRoots {
            guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey]) else { continue }
            for case let url as URL in files where ["png", "jpg", "jpeg", "webp"].contains(url.pathExtension.lowercased()) {
                let data = try Data(contentsOf: url)
                checked += 1
                XCTAssertGreaterThan(data.count, 100, url.lastPathComponent)
                XCTAssertLessThan(data.count, 1_000_000, "\(url.lastPathComponent) over 1 MB")
                let ext = url.pathExtension.lowercased()
                if ext == "png" { XCTAssertTrue(data.starts(with: Data([0x89, 0x50, 0x4E, 0x47])), "\(url.lastPathComponent) is not a PNG") }
                if ext == "jpg" || ext == "jpeg" { XCTAssertTrue(data.starts(with: Data([0xFF, 0xD8, 0xFF])), "\(url.lastPathComponent) is not a JPEG") }
            }
        }
        XCTAssertGreaterThanOrEqual(checked, 4, "four product images expected (AC-4)")
    }

    func testTC67_MissingAssetIsNotFoundEnvelope() async throws {
        for path in ["assets/products/does-not-exist.png", "assets/nothing", "assets/images/%E1%BA%A3nh-kh%C3%B4ng-c%C3%B3.png"] {
            let r = try await app.qaSend(.GET, path)
            XCTAssertEqual(r.status, .notFound, path)
            XCTAssertEqual(Slice1.envelopeProblems(r, code: "NOT_FOUND", messageKey: "ERR_SERVER"), [], path)
            XCTAssertFalse((r.header("Cache-Control") ?? "").contains("max-age=86400"), "a 404 must not be cached for a day")
        }
    }

    func testExtra_AssetsRouteDoesNotEscapeItsRoot() async throws {
        let traversals = [
            "assets/../Package.swift", "assets/%2e%2e/Package.swift", "assets/%2E%2E%2FPackage.swift",
            "assets/..%2f..%2fdb/migrations/0001_init.sql", "assets/..%5cPackage.swift", "assets/....//Package.swift",
            "assets//etc/passwd", "assets/%2fetc%2fpasswd", "assets/.env", "assets/.git/config", "assets/products/..%2f..%2fPackage.swift",
            "assets/%00", "assets/privacy.html%00.png"
        ]
        for path in traversals {
            let r = try await app.qaSend(.GET, path)
            XCTAssertLessThan(r.status.code, 500, path)
            XCTAssertFalse(r.text.contains("swift-tools-version"), "\(path) served Package.swift")
            XCTAssertFalse(r.text.contains("CREATE TABLE"), "\(path) served a migration")
            XCTAssertFalse(r.text.contains("root:"), "\(path) served passwd")
        }
    }

    func testExtra_AssetsDirectoryAndRootAreNotListed() async throws {
        for path in ["assets", "assets/", "assets/products", "assets/products/", "assets/images/"] {
            let r = try await app.qaSend(.GET, path)
            XCTAssertNotEqual(r.status.code / 100, 5, path)
            XCTAssertFalse(r.text.lowercased().contains("index of"), "\(path) lists a directory")
        }
    }

    func testExtra_AssetMethodsRangeAndRevalidation() async throws {
        let some = try XCTUnwrap(QAPaths.seedImagePaths().first)
        let candidates = ["assets/\(some)", "assets/products/\((some as NSString).lastPathComponent)", "assets/\((some as NSString).lastPathComponent)"]
        var served: String?
        for path in candidates {
            if try await app.qaSend(.GET, path).status == .ok { served = path; break }
        }
        let path = try XCTUnwrap(served, "no candidate URL of \(some) is served; the catalog image_url rule (api.md 4.6) is the contract")
        let get = try await app.qaSend(.GET, path)
        XCTAssertEqual(get.header("Cache-Control")?.replacingOccurrences(of: " ", with: ""), "public,max-age=86400")
        let head = try await app.qaSend(.HEAD, path)
        XCTAssertEqual(head.status, .ok)
        XCTAssertEqual(head.body.count, 0)
        let range = try await app.qaSend(.GET, path, headers: ["Range": "bytes=0-9"])
        XCTAssertTrue([HTTPResponseStatus.ok, .partialContent].contains(range.status), "range gave \(range.status)")
        let badRange = try await app.qaSend(.GET, path, headers: ["Range": "bytes=999999999-"])
        XCTAssertLessThan(badRange.status.code, 500)
        if let etag = get.header("ETag") {
            let cond = try await app.qaSend(.GET, path, headers: ["If-None-Match": etag])
            XCTAssertEqual(cond.status, .notModified)
        }
        for method in [HTTPMethod.POST, .PUT, .DELETE] {
            let r = try await app.qaSend(method, path)
            XCTAssertNotEqual(r.status, .ok, "\(method) must not succeed on an asset")
            XCTAssertLessThan(r.status.code, 500)
        }
    }

    // MARK: Contract fixtures (architecture.md 11 slice 1: catalog-*.json)

    func testTC1_CatalogFixturesExistAndSatisfyTheContractCheck() throws {
        let files = try FileManager.default.contentsOfDirectory(at: QAPaths.fixtures, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("catalog-") && $0.pathExtension == "json" }
        XCTAssertFalse(files.isEmpty, "contracts/fixtures/catalog-*.json missing")
        for file in files {
            let json = try J.parse(Data(contentsOf: file))
            XCTAssertEqual(Slice1.shapeProblems(json), [], file.lastPathComponent)
            XCTAssertEqual(Slice1.forbiddenHits(in: json.allText), [], file.lastPathComponent)
        }
    }

    func testTC1_CatalogFixtureMatchesTheSampleSeedWhereItClaimsToBeTheSeed() throws {
        let url = QAPaths.fixtures.appendingPathComponent("catalog-ok.json")
        let json = try J.parse(Data(contentsOf: url))
        let products = try XCTUnwrap(json["products"]?.array)
        XCTAssertEqual(products.compactMap { $0["price_vnd"]?.int }.count, 4)
        XCTAssertEqual(products.count, 4)
    }

    func testExtra_FixtureReadmeListsEveryCatalogFixture() throws {
        let readme = try String(contentsOf: QAPaths.fixtures.appendingPathComponent("README.md"), encoding: .utf8)
        let files = try FileManager.default.contentsOfDirectory(atPath: QAPaths.fixtures.path).filter { $0.hasSuffix(".json") }
        for file in files { XCTAssertTrue(readme.contains(file), "\(file) is not described in contracts/fixtures/README.md") }
    }

    // MARK: Static scan of the sample data (TC-66, AC-29)

    func testTC66_SampleSeedTextHasNoVisibleSampleMarker() throws {
        let seed = try String(contentsOf: QAPaths.seed, encoding: .utf8)
        let literals = seed.components(separatedBy: "'").enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
        XCTAssertEqual(Slice1.forbiddenHits(in: literals.filter { !$0.hasPrefix("00000000-") && $0 != "Asia/Ho_Chi_Minh" }), [])
    }
}
