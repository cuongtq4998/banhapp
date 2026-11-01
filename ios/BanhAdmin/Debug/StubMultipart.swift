#if DEBUG
import Foundation
import UIKit

/// Reads the multipart body of the cake upload: text fields and the one file of the stub backend.
nonisolated enum StubMultipart {
    struct Parts {
        var fields: [String: String] = [:]
        var files: [Data] = []
    }

    static func parse(_ request: URLRequest) -> Parts {
        guard let type = request.value(forHTTPHeaderField: "Content-Type"), let range = type.range(of: "boundary="),
              let body = request.httpBody
        else { return Parts() }
        let boundary = Data("--\(type[range.upperBound...])".utf8)
        let separator = Data("\r\n\r\n".utf8)
        var parts = Parts()
        var position = body.startIndex
        var chunks: [Data] = []
        while let found = body.range(of: boundary, in: position..<body.endIndex) {
            chunks.append(body[position..<found.lowerBound])
            position = found.upperBound
        }
        for chunk in chunks.dropFirst() {
            guard let split = chunk.range(of: separator) else { continue }
            let header = String(decoding: chunk[chunk.startIndex..<split.lowerBound], as: UTF8.self)
            var content = Data(chunk[split.upperBound...])
            if content.suffix(2) == Data("\r\n".utf8) { content.removeLast(2) }
            guard let nameRange = header.range(of: "name=\"") else { continue }
            let name = String(header[nameRange.upperBound...].prefix { $0 != "\"" })
            if header.contains("filename=") { parts.files.append(content) } else { parts.fields[name] = String(decoding: content, as: UTF8.self) }
        }
        return parts
    }

    /// JPEG signature, size within 5,242,880 bytes, each side 200 to 4096 pixels (api/07 10.17).
    static func imageProblem(_ files: [Data]) -> (status: Int, code: String, field: String)? {
        guard let file = files.first, !file.isEmpty else { return (422, "IMAGE_REQUIRED", "image") }
        if files.count > 1 { return (422, "IMAGE_INVALID", "image") }
        if file.count > 5_242_880 { return (413, "IMAGE_TOO_LARGE", "image") }
        guard file.starts(with: [0xFF, 0xD8, 0xFF]), let image = UIImage(data: file) else { return (422, "IMAGE_TYPE_UNSUPPORTED", "image") }
        let side = (Int(image.size.width * image.scale), Int(image.size.height * image.scale))
        guard (200...4096).contains(side.0), (200...4096).contains(side.1) else { return (422, "IMAGE_DIMENSIONS_INVALID", "image") }
        return nil
    }
}
#endif
