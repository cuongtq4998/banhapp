/// State of data that a screen shows: not yet known, known, or not obtainable.
nonisolated enum Load<Value> {
    case loading
    case ready(Value)
    case failed(LoadFailure)

    func flatMap<Result>(_ transform: (Value) -> Load<Result>) -> Load<Result> {
        switch self {
        case .ready(let value): transform(value)
        case .loading: .loading
        case .failed(let failure): .failed(failure)
        }
    }

    func map<Result>(_ transform: (Value) -> Result) -> Load<Result> {
        flatMap { .ready(transform($0)) }
    }
}

extension Load: Equatable where Value: Equatable {}

/// Why data could not be obtained; the screens pick their message from it (UI document 5.10).
nonisolated enum LoadFailure: Equatable, Sendable {
    /// No connection: the message names the network.
    case network
    /// Any other cause: the screen's generic message.
    case other
}

extension Load {
    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }
}
