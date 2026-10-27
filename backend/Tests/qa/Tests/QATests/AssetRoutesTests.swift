import XCTest
import XCTVapor
import Crypto
@testable import AppUnderTest

final class AssetRoutesTests: StaticContentBase {

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

}
