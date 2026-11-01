/// State of data that a screen shows: not yet known, known, or not obtainable.
public enum Load<Value> {
    case loading
    case ready(Value)
    case failed(LoadFailure)

    public var isLoading: Bool {
        if case .loading = self { true } else { false }
    }

    public var value: Value? {
        if case .ready(let value) = self { value } else { nil }
    }
}

extension Load: Equatable where Value: Equatable {}
extension Load: Sendable where Value: Sendable {}

/// Why data could not be obtained; the screens pick their message from it.
public enum LoadFailure: Equatable, Sendable {
    /// No connection: the message names the network.
    case network
    /// Any other cause: the screen's generic message.
    case other
}
