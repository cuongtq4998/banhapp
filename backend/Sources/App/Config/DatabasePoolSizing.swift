/// Fluent keeps one connection pool per event loop, so the real ceiling is
/// `eventLoops * connectionsPerLoop`. The rule below keeps that product at or
/// under `DATABASE_POOL_MAX`, which matters on a free database tier with a
/// small connection quota.
enum DatabasePoolSizing {
    /// Fewer loops than the budget, otherwise even one connection per loop
    /// would exceed it.
    static func eventLoopCount(poolMax: Int, coreCount: Int) -> Int {
        max(1, min(coreCount, poolMax))
    }

    /// Rounded down: unused budget is better than an exceeded one.
    static func connectionsPerLoop(poolMax: Int, eventLoopCount: Int) -> Int {
        max(1, poolMax / max(1, eventLoopCount))
    }
}
