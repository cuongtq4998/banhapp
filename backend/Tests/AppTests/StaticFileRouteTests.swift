import XCTVapor
import BanhContracts
@testable import App

final class StaticFileRouteTests: XCTestCase {
    private var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        // Serve the real files of `backend/assets`, whatever the test's working directory.
        app.directory.workingDirectory = TestPaths.backend.path + "/"
        try await configure(app, config: .localWithShop())
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func assertNotFoundEnvelope(_ res: XCTHTTPResponse, _ path: String, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(res.status, .notFound, path, file: file, line: line)
        XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error.code, "NOT_FOUND", path, file: file, line: line)
    }

    func testEverySeededImagePathIsServed() async throws {
        for product in CatalogTestData.snapshot.products {
            try await app.test(.GET, "assets/\(product.imagePath)") { res async throws in
                XCTAssertEqual(res.status, .ok, product.imagePath)
                XCTAssertEqual(res.headers.first(name: .cacheControl), "public, max-age=31536000, immutable")
                XCTAssertEqual(res.headers.contentType, .png)
                XCTAssertGreaterThan(res.body.readableBytes, 0)
            }
        }
    }

    func testImageHasValidators() async throws {
        var tag = ""
        try await app.test(.GET, "assets/images/banana.png") { res async throws in
            tag = try XCTUnwrap(res.headers.first(name: .eTag))
        }
        try await app.test(.GET, "assets/images/banana.png", headers: ["If-None-Match": tag]) { res async throws in
            XCTAssertEqual(res.status, .notModified)
        }
    }

    func testTheVersionQueryIsIgnored() async throws {
        try await app.test(.GET, "assets/images/banana.png?v=a547ade3") { res async throws in
            XCTAssertEqual(res.status, .ok)
        }
        try await app.test(.GET, "assets/images/banana.png?v=whatever&x=1") { res async throws in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testMissingFilesAnswerNoStore() async throws {
        for path in ["assets/images/nothing.png", "assets/images/..%2fbanana.png", "assets/other/banana.png"] {
            try await app.test(.GET, path) { res async throws in
                XCTAssertEqual(res.status, .notFound, path)
                XCTAssertEqual(res.headers.first(name: .cacheControl), "no-store", path)
            }
        }
    }

    func testImageURLsInTheFixtureCarryTheHashOfTheFile() throws {
        let fixture = try CatalogTestData.fixture("catalog-ok.json")
        for product in fixture.products {
            let record = try XCTUnwrap(CatalogTestData.snapshot.products.first { $0.slug == product.slug })
            XCTAssertEqual(CatalogTestData.assets.imageURL(forPath: record.imagePath), product.imageURL)
        }
    }

    func testMissingImageIsNotFound() async throws {
        try await app.test(.GET, "assets/images/nothing.png") { res async throws in try self.assertNotFoundEnvelope(res, "missing") }
        try await app.test(.GET, "assets") { res async throws in try self.assertNotFoundEnvelope(res, "bare") }
        try await app.test(.GET, "assets/images") { res async throws in try self.assertNotFoundEnvelope(res, "directory") }
    }

    func testPathTraversalIsRefused() async throws {
        let attempts = [
            "assets/../db/seed/sample.png",
            "assets/images/../../Package.swift",
            "assets/%2e%2e/Package.swift",
            "assets/images/%2e%2e%2f%2e%2e%2fPackage.swift",
            "assets/images/..%2fbanana.png",
            "assets/images/%5c..%5cbanana.png",
            "assets/images/.hidden.png"
        ]
        for path in attempts {
            try await app.test(.GET, path) { res async throws in
                XCTAssertNotEqual(res.status, .ok, path)
                XCTAssertFalse(res.body.string.contains("swift-tools-version"), path)
            }
        }
    }

    func testOnlyImagesAreServedFromTheAssetsRoute() async throws {
        try await app.test(.GET, "assets/privacy.html") { res async throws in try self.assertNotFoundEnvelope(res, "html") }
    }

    func testPrivacyPageIsHTMLInVietnamese() async throws {
        try await app.test(.GET, "privacy") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: .contentType), "text/html; charset=utf-8")
            XCTAssertEqual(res.headers.first(name: .cacheControl), "no-cache")
            let text = res.body.string
            for word in ["Họ tên", "Số điện thoại", "Địa chỉ", "Ghi chú", "Nơi lưu trữ", "Thời gian lưu giữ"] {
                XCTAssertTrue(text.contains(word), word)
            }
        }
    }

    func testPrivacyPageHoldsNoPaymentInstruction() throws {
        // FR-19, AC-27: the statement says nothing about paying.
        let text = try String(contentsOfFile: TestPaths.backend.path + "/assets/privacy.html", encoding: .utf8).lowercased()
        for word in ["thanh toán", "chuyển khoản", "payment"] {
            XCTAssertFalse(text.contains(word), word)
        }
    }

    func testPlainNameRules() {
        let dir = "/srv/assets/"
        XCTAssertEqual(AssetRoutes.filePath(forSegments: ["images", "a.PNG"], in: dir), "/srv/assets/images/a.PNG")
        XCTAssertNil(AssetRoutes.filePath(forSegments: [], in: dir))
        XCTAssertNil(AssetRoutes.filePath(forSegments: ["..", "a.png"], in: dir))
        XCTAssertNil(AssetRoutes.filePath(forSegments: ["a/b.png"], in: dir))
        XCTAssertNil(AssetRoutes.filePath(forSegments: ["a\\b.png"], in: dir))
        XCTAssertNil(AssetRoutes.filePath(forSegments: ["a\0.png"], in: dir))
        XCTAssertNil(AssetRoutes.filePath(forSegments: [""], in: dir))
        XCTAssertNil(AssetRoutes.filePath(forSegments: ["a.txt"], in: dir))
        XCTAssertNil(AssetRoutes.filePath(forSegments: ["noextension"], in: dir))
    }
}
