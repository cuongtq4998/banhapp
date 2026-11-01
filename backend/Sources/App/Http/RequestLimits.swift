import Vapor

enum RequestLimits {
    /// Largest accepted request body: api.md section 1 (8 KB). An order with
    /// the maximum number of lines is far smaller, so a bigger body is a
    /// client defect or an attack. Vapor's own default is 16 KB.
    static let maxBodyBytes = 8 * 1_024

    /// Vapor rejects a body of `maxSize` bytes or more (verified in
    /// `Request+BodyStream.swift`, and by a test), so one byte is added to
    /// make a body of exactly 8 KB pass and the next byte fail.
    static var maxBodySize: ByteCount { ByteCount(value: maxBodyBytes + 1) }

    /// `POST /v1/owner/cakes` is the one route with a bigger body: the picture
    /// (`ImageInspector.maxBytes`) plus 64 KB for the form fields and the
    /// multipart boundaries (ADR-0025, api/05 section 9).
    static let maxUploadBytes = ImageInspector.maxBytes + 65_536

    /// One byte more for the same reason as `maxBodySize`.
    static var maxUploadSize: ByteCount { ByteCount(value: maxUploadBytes + 1) }
}
