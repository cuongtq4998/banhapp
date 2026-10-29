import Foundation

/// Where the order draft lives between launches. The flow talks to this protocol; tests and the UI
/// test stub use the in-memory copy.
protocol DraftStore {
    /// The saved draft, or nil when there is none, it is unreadable, or it is older than 24 hours
    /// (an expired draft is deleted).
    func load(now: Date) -> OrderDraft?
    func save(_ draft: OrderDraft)
    func clear()
}

final class InMemoryDraftStore: DraftStore {
    private var draft: OrderDraft?

    init(draft: OrderDraft? = nil) {
        self.draft = draft
    }

    func load(now: Date) -> OrderDraft? {
        guard let draft, !draft.isExpired(at: now) else {
            draft = nil
            return nil
        }
        return draft
    }

    func save(_ draft: OrderDraft) { self.draft = draft }
    func clear() { draft = nil }
}

/// A JSON file in the app's private storage: not backed up or synced, and encrypted while the device
/// is locked (ADR-0011).
final class FileDraftStore: DraftStore {
    private static let fileName = "order-draft.json"

    private let url: URL

    init(url: URL) {
        self.url = url
    }

    static func inApplicationSupport(fileManager: FileManager = .default) throws -> FileDraftStore {
        let directory = try fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return FileDraftStore(url: directory.appendingPathComponent(fileName))
    }

    func load(now: Date) -> OrderDraft? {
        guard let data = try? Data(contentsOf: url),
              let draft = try? JSONDecoder.draft.decode(OrderDraft.self, from: data),
              draft.version == OrderDraft.currentVersion, !draft.isExpired(at: now) else {
            clear()
            return nil
        }
        return draft
    }

    func save(_ draft: OrderDraft) {
        guard let data = try? JSONEncoder.draft.encode(draft),
              (try? data.write(to: url, options: [.atomic, .completeFileProtection])) != nil else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var excluded = url
        try? excluded.setResourceValues(values)
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}

private extension JSONEncoder {
    static var draft: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var draft: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
