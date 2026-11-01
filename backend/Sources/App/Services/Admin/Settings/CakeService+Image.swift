import Foundation
import Crypto
import BanhContracts

/// Reading the upload: text parts become the same JSON-like values the other
/// owner forms use, and the picture is checked from its own bytes (ADR-0025).
extension CakeService {
    /// A text part sent once; a repeated one is not a usable value.
    static func values(of form: MultipartFields) -> [String: JSONValue] {
        var body: [String: JSONValue] = [:]
        for name in Set(form.parts.filter { !$0.isFile }.map(\.name)) {
            guard let text = form.text(name) else { body[name] = .array([]); continue }
            body[name] = name == "price_vnd" ? (Int(text).map(JSONValue.int) ?? .string(text)) : .string(text)
        }
        return body
    }

    /// Exactly one file part named `image`. Too many bytes is a 413 at once;
    /// every other problem joins the field list.
    static func checkImage(_ form: MultipartFields, _ reader: inout FormReader) throws -> StoredImage? {
        let files = form.all("image").filter(\.isFile)
        if files.contains(where: { $0.bytes.count > ImageInspector.maxBytes }) { throw APIError(.imageTooLarge) }
        guard let file = files.first, !file.bytes.isEmpty else {
            reader.add("image", "IMAGE_REQUIRED", "REQUIRED")
            return nil
        }
        if files.count > 1 { reader.add("image", "IMAGE_INVALID", "INVALID"); return nil }
        guard let info = ImageInspector.inspect(file.bytes) else {
            reader.add("image", "IMAGE_TYPE_UNSUPPORTED", "TYPE_UNSUPPORTED")
            return nil
        }
        guard ImageInspector.sides.contains(info.width), ImageInspector.sides.contains(info.height) else {
            reader.add("image", "IMAGE_DIMENSIONS_INVALID", "DIMENSIONS_INVALID")
            return nil
        }
        let digest = SHA256.hash(data: file.bytes).map { String(format: "%02x", $0) }.joined()
        return StoredImage(contentType: info.kind.rawValue, bytes: file.bytes, width: info.width, height: info.height, sha256: digest)
    }
}
