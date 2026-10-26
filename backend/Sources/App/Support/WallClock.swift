import Foundation

/// Source of "now". Named `WallClock` because `Clock` is already a Swift
/// standard library protocol and shadowing it would confuse readers.
///
/// Business rules never call `Date()` directly, so tests can pin the instant
/// (lead time and horizon depend on the current Vietnam date).
protocol WallClock: Sendable {
    func now() -> Date
}

struct SystemWallClock: WallClock {
    func now() -> Date { Date() }
}

/// Always answers the same instant; for tests.
struct FixedWallClock: WallClock {
    let instant: Date
    func now() -> Date { instant }
}
