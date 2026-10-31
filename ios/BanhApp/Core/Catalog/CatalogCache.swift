import Foundation

/// Local copy of the catalog. Reading never throws: a missing or damaged copy is simply absent.
nonisolated protocol CatalogCache: Sendable {
    func read() async -> CachedCatalog?

    /// Best effort: the cache only saves time, so a failed write is not an error.
    func write(_ entry: CachedCatalog) async
}

/// Stores the cache as one JSON file in app-private storage. The catalog is public shop data, not
/// personal data. An actor so the file work runs off the main thread and writes never interleave.
actor FileCatalogCache: CatalogCache {
    static let defaultFileName = "catalog-cache.json"

    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func inApplicationSupport(fileName: String = defaultFileName) throws -> FileCatalogCache {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return FileCatalogCache(fileURL: directory.appending(path: fileName))
    }

    func read() -> CachedCatalog? {
        // A copy written by an older app version may not match the current model: treat it as absent.
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(CachedCatalog.self, from: data)
    }

    func write(_ entry: CachedCatalog) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        // Atomic: a killed process never leaves a half-written file behind.
        try? data.write(to: fileURL, options: .atomic)
        excludeFromBackup()
    }

    // The copy is rebuilt from the server, so it has no place in the user's device backup.
    private func excludeFromBackup() {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = fileURL
        try? url.setResourceValues(values)
    }
}

/// Keeps the copy for the life of the process only; used where nothing should reach the disk.
actor InMemoryCatalogCache: CatalogCache {
    private var entry: CachedCatalog?

    init(entry: CachedCatalog? = nil) {
        self.entry = entry
    }

    func read() -> CachedCatalog? { entry }

    func write(_ entry: CachedCatalog) { self.entry = entry }
}
