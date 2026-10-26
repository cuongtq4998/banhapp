import XCTest
import XCTVapor
import Crypto
@testable import AppUnderTest

/// Slice 1: `/privacy` (api.md 4.5), `/assets/*` (4.6), asset files in the
/// repository, and the contract fixtures `catalog-*.json` (architecture.md 11).
/// Needs no database. Rules of api.md v1.6 and ADR-0017 (images under
/// `/assets/images/`, privacy page only at `/privacy`).
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
                                ("purpose", "muc dich"), ("who sees it", "ai xem"), ("storage place", "noi luu tru"),
                                ("retention", "luu giu")] {
            XCTAssertTrue(folded.contains(needle), "privacy page does not mention \(label) (api.md 4.5)")
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
            XCTAssertTrue(path.hasPrefix("images/"), "image_path is relative to backend/assets and under images/ (api.md 4.6): \(path)")
            XCTAssertFalse(path.contains(".."))
            XCTAssertTrue(FileManager.default.fileExists(atPath: QAPaths.backend.appendingPathComponent("assets/" + path).path), "no file backend/assets/\(path)")
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
        for path in ["assets/products/does-not-exist.png", "assets/nothing", "assets/images/does-not-exist.png",
                     "assets/images/%E1%BA%A3nh-kh%C3%B4ng-c%C3%B3.png", "assets/privacy.html", "assets/images"] {
            let r = try await app.qaSend(.GET, path)
            XCTAssertEqual(r.status, .notFound, path)
            XCTAssertEqual(Slice1.envelopeProblems(r, code: "NOT_FOUND", messageKey: "ERR_SERVER"), [], path)
            XCTAssertEqual(r.header("Cache-Control"), "no-store", "api.md 4.6: a 404 is no-store: \(path)")
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

    func testExtra_AssetMethodsRangeAndRevalidation() async throws {
        let path = "assets/images/banana.png"
        let get = try await app.qaSend(.GET, path)
        XCTAssertEqual(get.status, .ok)
        XCTAssertEqual(get.header("Cache-Control"), "public, max-age=31536000, immutable", "api.md 4.6")
        XCTAssertTrue(get.header("Content-Type")?.hasPrefix("image/png") ?? false, get.header("Content-Type") ?? "nil")
        XCTAssertTrue(get.body.starts(with: Data([0x89, 0x50, 0x4E, 0x47])))
        let withVersion = try await app.qaSend(.GET, path + "?v=deadbeef")
        XCTAssertEqual(withVersion.status, .ok, "the version query is ignored")
        XCTAssertEqual(withVersion.body, get.body)
        let head = try await app.qaSend(.HEAD, path)
        XCTAssertLessThan(head.status.code, 500)
        // The in-memory tester does not strip HEAD bodies the way the HTTP server does; not observable here.
        let range = try await app.qaSend(.GET, path, headers: ["Range": "bytes=0-9"])
        XCTAssertTrue([HTTPResponseStatus.ok, .partialContent].contains(range.status), "range gave \(range.status)")
        let badRange = try await app.qaSend(.GET, path, headers: ["Range": "bytes=999999999-"])
        XCTAssertLessThan(badRange.status.code, 500)
        let garbageRange = try await app.qaSend(.GET, path, headers: ["Range": "bytes=abc"])
        XCTAssertLessThan(garbageRange.status.code, 500)
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

    /// api.md 4.6: only `images/` is served; extension allow-list; hidden names refused.
    func testExtra_OnlyImagesWithImageExtensionsAreServed() async throws {
        let paths = [
            "assets/images/..%2fprivacy.html", "assets/images/%2e%2e/privacy.html", "assets/images/%2E%2E%2Fprivacy.html",
            "assets/images/../privacy.html", "assets/images/sub/../banana.png", "assets/images/.hidden.png",
            "assets/images/banana.png/", "assets/images//banana.png", "assets/images/banana.png%00", "assets/images/banana.png%00.txt",
            "assets/images/%5c..%5cprivacy.html", "assets/images/..\\privacy.html", "assets/images/privacy.html",
            "assets/images/banana.png.txt", "assets/images/banana", "assets/images/%252e%252e/privacy.html",
            "assets/images/%C0%AE%C0%AE/privacy.html", "assets/images/%EF%BC%8E%EF%BC%8E/privacy.html"
        ]
        for path in paths {
            let r = try await app.qaSend(.GET, path)
            XCTAssertLessThan(r.status.code, 500, path)
            XCTAssertFalse(r.text.contains("<!DOCTYPE html"), "\(path) served the privacy page")
            if r.status == .ok {
                XCTAssertTrue(r.header("Content-Type")?.hasPrefix("image/") ?? false, "\(path) served a non-image: \(r.header("Content-Type") ?? "nil")")
            }
        }
        let upper = try await app.qaSend(.GET, "assets/images/banana.PNG")
        XCTAssertLessThan(upper.status.code, 500, "case variants are 200 on a case-insensitive disk and 404 elsewhere, never an error")
    }

    func testExtra_ImageUrlVersionIsTheFileSha256Prefix() throws {
        let fixture = try J.parse(Data(contentsOf: QAPaths.fixtures.appendingPathComponent("catalog-ok.json")))
        for product in try XCTUnwrap(fixture["products"]?.array) {
            let url = try XCTUnwrap(product["image_url"]?.string)
            let parts = url.components(separatedBy: "?v=")
            XCTAssertEqual(parts.count, 2, url)
            let file = QAPaths.backend.appendingPathComponent("assets" + parts[0].dropFirst("/assets".count))
            let digest = SHA256.hash(data: try Data(contentsOf: file)).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(String(digest.prefix(8)), parts[1], "fixture hash of \(parts[0]) is stale (README.md of the fixtures)")
        }
    }

    func testExtra_AssetsDirectoryAndRootAreNotListed() async throws {
        for path in ["assets", "assets/", "assets/images", "assets/images/"] {
            let r = try await app.qaSend(.GET, path)
            XCTAssertEqual(r.status, .notFound, path)
            XCTAssertFalse(r.text.lowercased().contains("index of"), "\(path) lists a directory")
        }
    }

    // MARK: Contract fixtures (architecture.md 11 slice 1: catalog-*.json)

    func testTC1_CatalogFixturesExistAndSatisfyTheContractCheck() throws {
        let ok = try J.parse(Data(contentsOf: QAPaths.fixtures.appendingPathComponent("catalog-ok.json")))
        XCTAssertEqual(Slice1.shapeProblems(ok), [], "catalog-ok.json")
        XCTAssertEqual(Slice1.forbiddenHits(in: ok.allText), [], "catalog-ok.json")

        // AC-33: zero active cakes, districts and slots is a valid 200 with empty lists.
        let empty = try J.parse(Data(contentsOf: QAPaths.fixtures.appendingPathComponent("catalog-empty.json")))
        XCTAssertEqual(Slice1.shapeProblems(empty, productCount: 0, minDistricts: 0, minSlots: 0), [], "catalog-empty.json")
        XCTAssertEqual(empty["products"]?.array?.count, 0)
        XCTAssertEqual(Slice1.forbiddenHits(in: empty.allText), [], "catalog-empty.json")
    }

    func testTC3_NotModifiedFixtureFollowsTheEtagContract() throws {
        let json = try J.parse(Data(contentsOf: QAPaths.fixtures.appendingPathComponent("catalog-not-modified.json")))
        XCTAssertEqual(json["status"]?.int, 304)
        XCTAssertEqual(json["body"], J.null, "a 304 has no body")
        let sent = try XCTUnwrap(json["request_headers"]?["If-None-Match"]?.string)
        let etag = try XCTUnwrap(json["response_headers"]?["ETag"]?.string)
        XCTAssertEqual(sent, etag, "a 304 repeats the matched tag")
        XCTAssertEqual(json["response_headers"]?["Cache-Control"]?.string, "no-cache")
        XCTAssertNotNil(etag.range(of: "^\"[0-9a-f]{32}\"$", options: .regularExpression), "api.md 4.1: quoted 32 lowercase hex characters: \(etag)")
        XCTAssertNil(json["response_headers"]?["Content-Type"], "a 304 does not repeat Content-Type")
    }

    func testExtra_FixtureReadmeListsEveryCatalogFixture() throws {
        let readme = try String(contentsOf: QAPaths.fixtures.appendingPathComponent("README.md"), encoding: .utf8)
        let files = try FileManager.default.contentsOfDirectory(atPath: QAPaths.fixtures.path).filter { $0.hasSuffix(".json") }
        XCTAssertGreaterThanOrEqual(files.count, 10)
        for file in files { XCTAssertTrue(readme.contains(file), "\(file) is not described in contracts/fixtures/README.md") }
    }

    // MARK: Static scan of the sample data (TC-66, AC-29)

    func testTC66_SampleSeedTextHasNoVisibleSampleMarker() throws {
        let seed = try String(contentsOf: QAPaths.seed, encoding: .utf8)
        let literals = seed.components(separatedBy: "'").enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
        XCTAssertEqual(Slice1.forbiddenHits(in: literals.filter { !$0.hasPrefix("00000000-") && $0 != "Asia/Ho_Chi_Minh" }), [])
    }
}
