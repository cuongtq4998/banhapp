import XCTest
@testable import App

/// The picture header reading of ADR-0025, without a database.
final class ImageInspectorTests: XCTestCase {
    func testPngAndJpegSizesComeFromTheHeader() {
        XCTAssertEqual(ImageInspector.inspect(TestImages.png(width: 1_234, height: 567)), ImageInfo(kind: .png, width: 1_234, height: 567))
        XCTAssertEqual(ImageInspector.inspect(TestImages.jpeg(width: 4_096, height: 200)), ImageInfo(kind: .jpeg, width: 4_096, height: 200))
    }

    func testJpegWithExtraSegmentsBeforeTheFrameIsRead() {
        // An EXIF-like and a comment segment come before the segments of the generated file.
        let bytes: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE1, 0, 6, 1, 2, 3, 4, 0xFF, 0xFE, 0, 4, 9, 9] + TestImages.jpeg(width: 800, height: 600).dropFirst(2)
        XCTAssertEqual(ImageInspector.inspect(bytes), ImageInfo(kind: .jpeg, width: 800, height: 600))
    }

    func testTheSignatureDecidesNotTheName() {
        XCTAssertNil(ImageInspector.inspect(Array("GIF89a....".utf8)))
        XCTAssertNil(ImageInspector.inspect([0xFF, 0xD8]))
        XCTAssertNil(ImageInspector.inspect([]))
        XCTAssertNil(ImageInspector.inspect([0xFF, 0xD8, 0xFF, 0xE0, 0, 2]), "no frame header")
        XCTAssertNil(ImageInspector.inspect([0xFF, 0xD8, 0xFF, 0xE0, 0xFF]), "cut short")
        var png = TestImages.png(width: 300, height: 300)
        png[12] = UInt8(ascii: "X")
        XCTAssertNil(ImageInspector.inspect(png), "the first chunk must be IHDR")
    }
}
