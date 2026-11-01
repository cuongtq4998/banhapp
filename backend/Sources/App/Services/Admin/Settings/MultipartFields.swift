import Foundation
import Vapor

/// The parts of a `multipart/form-data` body, in order. Text parts are read as
/// UTF-8; a file part keeps its bytes. A body that cannot be parsed is a plain
/// `VALIDATION_FAILED`.
struct MultipartFields {
    struct Part {
        let name: String
        let isFile: Bool
        let bytes: [UInt8]

        var text: String? { String(bytes: bytes, encoding: .utf8) }
    }

    let parts: [Part]

    init(body: ByteBuffer, contentType: HTTPMediaType?) throws {
        guard let contentType, contentType.type == "multipart", contentType.subType == "form-data",
              let boundary = contentType.parameters["boundary"], !boundary.isEmpty else { throw APIError(.validationFailed) }
        let parser = MultipartParser(boundary: boundary)
        var parts: [Part] = []
        var headers = HTTPHeaders(), data: [UInt8] = []
        parser.onHeader = { headers.add(name: $0, value: $1) }
        parser.onBody = { data.append(contentsOf: $0.readableBytesView) }
        parser.onPartComplete = {
            let disposition = headers.contentDisposition
            parts.append(Part(name: disposition?.name ?? "", isFile: disposition?.filename != nil, bytes: data))
            headers = HTTPHeaders()
            data = []
        }
        do { try parser.execute(body) } catch { throw APIError(.validationFailed) }
        self.parts = parts
    }

    func all(_ name: String) -> [Part] { parts.filter { $0.name == name } }

    /// The text of a field sent once; absent, repeated or a file is nil.
    func text(_ name: String) -> String? {
        let found = all(name)
        return found.count == 1 && !found[0].isFile ? found[0].text : nil
    }

    var names: Set<String> { Set(parts.map(\.name)) }
}
