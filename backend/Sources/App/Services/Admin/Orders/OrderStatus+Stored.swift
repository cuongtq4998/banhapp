import Foundation

extension OrderStatus {
    /// Old words kept in append-only history, never rewritten.
    private static let legacyWords: [String: OrderStatus] = [
        "New": .received, "Confirmed": .processing, "Completed": .finished
    ]

    /// Reads a stored word, mapping old ones; nil when unknown.
    /// The one function for every `order_event` read.
    static func fromStored(_ word: String) -> OrderStatus? {
        legacyWords[word] ?? OrderStatus(rawValue: word)
    }

    /// Quoted list for a SQL `IN (...)`; built from fixed enum values only.
    static func sqlList(_ statuses: [OrderStatus]) -> String {
        statuses.map { "'\($0.rawValue)'" }.joined(separator: ", ")
    }
}
