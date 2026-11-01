import Foundation

/// Pictures made in code: only the signature and the header size matter to the server.
enum QAImages {
    static func be32(_ value: UInt32) -> [UInt8] { [UInt8(value >> 24), UInt8((value >> 16) & 255), UInt8((value >> 8) & 255), UInt8(value & 255)] }

    /// A PNG signature with an IHDR of the given size; `pad` extra bytes follow so the file can be large.
    static func png(width: UInt32 = 800, height: UInt32 = 600, pad: Int = 0) -> Data {
        var bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        bytes += be32(13) + Array("IHDR".utf8) + be32(width) + be32(height) + [8, 2, 0, 0, 0] + [0, 0, 0, 0]
        bytes += be32(0) + Array("IEND".utf8) + [0xAE, 0x42, 0x60, 0x82]
        return Data(bytes) + Data(repeating: 0, count: pad)
    }

    /// A JPEG with SOI, a baseline frame header (SOF0) of the given size and EOI.
    static func jpeg(width: UInt16 = 800, height: UInt16 = 600, pad: Int = 0) -> Data {
        var bytes: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE0, 0, 16] + Array("JFIF".utf8) + [0, 1, 1, 0, 0, 1, 0, 1, 0, 0]
        bytes += [0xFF, 0xC0, 0, 17, 8, UInt8(height >> 8), UInt8(height & 255), UInt8(width >> 8), UInt8(width & 255), 3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1]
        bytes += [0xFF, 0xD9]
        return Data(bytes) + Data(repeating: 0, count: pad)
    }

    /// A multipart body of `fields` and (optionally) one or more file parts named `image`.
    static func multipart(boundary: String = "qaBoundary7MA4YWxk", fields: [String: String], files: [(name: String, type: String, data: Data)]) -> (body: Data, type: String) {
        var body = Data()
        for (key, value) in fields.sorted(by: { $0.key < $1.key }) {
            body += Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n".utf8)
        }
        for file in files {
            body += Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"\(file.name)\"\r\nContent-Type: \(file.type)\r\n\r\n".utf8)
            body += file.data + Data("\r\n".utf8)
        }
        body += Data("--\(boundary)--\r\n".utf8)
        return (body, "multipart/form-data; boundary=\(boundary)")
    }
}
