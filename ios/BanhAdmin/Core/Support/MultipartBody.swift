import Foundation

/// A `multipart/form-data` body: text fields, then one file (`POST /v1/owner/cakes`).
nonisolated struct MultipartBody {
    let boundary: String
    private(set) var data = Data()

    init(boundary: String = "banh-\(UUID().uuidString)") { self.boundary = boundary }

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    mutating func addField(_ name: String, _ value: String) {
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
    }

    mutating func addFile(_ name: String, filename: String, mimeType: String, bytes: Data) {
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(mimeType)\r\n\r\n")
        data.append(bytes)
        append("\r\n")
    }

    /// The finished body: the closing boundary is added.
    var finished: Data {
        var copy = data
        copy.append(Data("--\(boundary)--\r\n".utf8))
        return copy
    }

    private mutating func append(_ text: String) { data.append(Data(text.utf8)) }
}
