import Logging

/// Keeps personal data and credentials out of the log at every level (BR-7,
/// api/05 section 9, defect D-4).
///
/// Libraries write what they handle when the level is `debug` or `trace`:
/// the PostgreSQL driver logs queries with bound values and raw rows, Fluent
/// logs queries, Vapor logs every decoded request head (the `Authorization`
/// header and the query string). None of that is ours to filter line by line,
/// so the rule is by origin:
/// - an event written by this module follows the log policy already (no name,
///   phone, address, note, e-mail address, token or code) and passes unchanged;
/// - an event written by any other module is dropped below `info`, and from
///   `info` up only its message and a short list of harmless metadata keys
///   (`allowedForeignMetadata`) are kept.
struct RedactingLogHandler: LogHandler {
    /// Metadata of library events that never holds user data: ids of the
    /// pool and connection, and the request id tag.
    static let allowedForeignMetadata: Set<String> = ["database-id", "psql_connection_id", "request-id"]

    /// The module of this file: `App` in the server, another name where the
    /// sources are compiled into a test package.
    static let ownSource: String = String("\(#fileID)".prefix { $0 != "/" })

    private let target: Logger
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level

    init(wrapping target: Logger) {
        self.target = target
        self.logLevel = target.logLevel
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        var merged = metadata.merging(event.metadata ?? [:]) { $1 }
        if event.source != Self.ownSource {
            guard event.level >= .info else { return }
            merged = merged.filter { Self.allowedForeignMetadata.contains($0.key) }
        }
        target.log(
            level: event.level, event.message, metadata: merged.isEmpty ? nil : merged,
            source: event.source, file: event.file, function: event.function, line: event.line
        )
    }
}

extension Logger {
    /// The same logger, with every event passing `RedactingLogHandler` first.
    func redacting() -> Logger {
        let inner = self
        return Logger(label: label) { _ in RedactingLogHandler(wrapping: inner) }
    }
}
