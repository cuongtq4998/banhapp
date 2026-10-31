import Foundation
import Logging
import NIOConcurrencyHelpers
@testable import AppUnderTest

/// Log capture and a secret-carrying error for the adversarial error-pipeline cases. Fake data only.

final class QALogCapture: @unchecked Sendable {
    // Invariant: `entries` is only touched under `lock`.
    private let lock = NIOLock()
    private var entries: [(message: String, metadata: Logger.Metadata)] = []
    var lines: [(message: String, metadata: Logger.Metadata)] { lock.withLock { entries } }
    func append(_ m: String, _ md: Logger.Metadata) { lock.withLock { entries.append((m, md)) } }
    func makeLogger() -> Logger { Logger(label: "qa") { _ in QAHandler(capture: self) } }
}

struct QAHandler: LogHandler {
    let capture: QALogCapture
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .trace
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }
    func log(event: LogEvent) { capture.append("\(event.message)", metadata.merging(event.metadata ?? [:]) { $1 }) }
}

struct SecretError: Error, CustomStringConvertible {
    var description: String { "SELECT * FROM customer_order WHERE phone='0900000000' password=hunter2" }
}
