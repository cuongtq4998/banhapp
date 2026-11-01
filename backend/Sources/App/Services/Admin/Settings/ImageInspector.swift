import Foundation

/// What the server learns about an uploaded picture without decoding it
/// (ADR-0025): the type from the file signature (never the header or the
/// name) and the size from the header, so a decompression bomb is refused
/// before any pixel is read.
struct ImageInfo: Equatable, Sendable {
    enum Kind: String, Sendable {
        case jpeg = "image/jpeg"
        case png = "image/png"
    }

    let kind: Kind
    let width: Int
    let height: Int
}

enum ImageInspector {
    static let maxBytes = 5_242_880
    static let sides = 200...4_096

    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    private static let jpegSignature: [UInt8] = [0xFF, 0xD8, 0xFF]

    /// Nil when the signature is neither JPEG nor PNG, or the header holds no size.
    static func inspect(_ bytes: [UInt8]) -> ImageInfo? {
        if bytes.starts(with: pngSignature) {
            return pngSize(bytes).map { ImageInfo(kind: .png, width: $0.width, height: $0.height) }
        }
        if bytes.starts(with: jpegSignature) {
            return jpegSize(bytes).map { ImageInfo(kind: .jpeg, width: $0.width, height: $0.height) }
        }
        return nil
    }

    /// The IHDR chunk comes first: 8 signature bytes, 4 length, "IHDR", width, height.
    private static func pngSize(_ b: [UInt8]) -> (width: Int, height: Int)? {
        guard b.count >= 24, Array(b[12..<16]) == Array("IHDR".utf8) else { return nil }
        return (bigEndian(b, 16), bigEndian(b, 20))
    }

    /// Walks the marker segments up to the first start-of-frame marker.
    private static func jpegSize(_ b: [UInt8]) -> (width: Int, height: Int)? {
        var i = 2
        while i + 4 <= b.count {
            guard b[i] == 0xFF else { return nil }
            let marker = b[i + 1]
            if marker == 0xFF { i += 1; continue }               // fill byte
            if marker == 0xD8 || marker == 0x01 || (0xD0...0xD7).contains(marker) { i += 2; continue }
            let length = Int(b[i + 2]) << 8 | Int(b[i + 3])
            let isFrame = (0xC0...0xCF).contains(marker) && ![0xC4, 0xC8, 0xCC].contains(marker)
            if isFrame {
                guard length >= 8, i + 9 <= b.count else { return nil }
                return (Int(b[i + 7]) << 8 | Int(b[i + 8]), Int(b[i + 5]) << 8 | Int(b[i + 6]))
            }
            if marker == 0xDA || length < 2 { return nil }       // scan data reached with no frame
            i += 2 + length
        }
        return nil
    }

    private static func bigEndian(_ b: [UInt8], _ at: Int) -> Int {
        Int(b[at]) << 24 | Int(b[at + 1]) << 16 | Int(b[at + 2]) << 8 | Int(b[at + 3])
    }
}
