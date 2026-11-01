import Foundation

/// Pictures made in code, so no binary file is stored in the repository. Only
/// the header matters to the server (ADR-0025): the pixel data is a filler.
enum TestImages {
    static func png(width: Int, height: Int, padTo size: Int = 0) -> [UInt8] {
        var bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13] + Array("IHDR".utf8)
        bytes += be32(width) + be32(height) + [8, 2, 0, 0, 0, 0, 0, 0, 0]
        bytes += [0, 0, 0, 0] + Array("IEND".utf8) + [0, 0, 0, 0]
        return padded(bytes, size)
    }

    static func jpeg(width: Int, height: Int, padTo size: Int = 0) -> [UInt8] {
        var bytes: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE0, 0, 16] + Array("JFIF".utf8) + [0, 1, 1, 0, 0, 1, 0, 1, 0, 0]
        bytes += [0xFF, 0xC0, 0, 17, 8] + be16(height) + be16(width) + [3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1]
        bytes += [0xFF, 0xDA, 0, 12, 3, 1, 0, 2, 0x11, 3, 0x11, 0, 63, 0, 0x55, 0xFF, 0xD9]
        return padded(bytes, size)
    }

    /// Filler after the end marker brings the file to `size` bytes exactly.
    private static func padded(_ bytes: [UInt8], _ size: Int) -> [UInt8] {
        bytes.count >= size ? bytes : bytes + [UInt8](repeating: 0, count: size - bytes.count)
    }

    private static func be16(_ value: Int) -> [UInt8] { [UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)] }
    private static func be32(_ value: Int) -> [UInt8] { be16(value >> 16) + be16(value & 0xFFFF) }
}

/// A `multipart/form-data` body: text fields and any number of files.
struct MultipartBody {
    let boundary = "Boundary-" + UUID().uuidString
    private(set) var data = Data()

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    mutating func text(_ name: String, _ value: String) {
        data.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
    }

    mutating func file(_ name: String, _ bytes: [UInt8], type: String = "image/jpeg") {
        data.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"photo\"\r\nContent-Type: \(type)\r\n\r\n".utf8))
        data.append(contentsOf: bytes)
        data.append(Data("\r\n".utf8))
    }

    var closed: Data { data + Data("--\(boundary)--\r\n".utf8) }
}
