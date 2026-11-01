import Foundation
import Logging

/// What the dispatcher needs from storage: who gets a push, and forgetting a
/// token the service called dead. `PushStore` is the database version.
protocol PushTokenStore: Sendable {
    func targets(shopID: UUID, now: Date) async throws -> [PushTarget]
    func clear(token: String) async throws
}

/// Sends the new-order push off the request path (FR-25, ADR-0024). The caller
/// starts it after the order transaction committed; nothing here can change the
/// order's answer. Each phone gets its own send with retries after 1, 5 and
/// 20 seconds on a throw; a dead token is deleted; one log line holds counts
/// only (no token, no order data).
struct PushDispatcher: Sendable {
    static let defaultRetryDelays: [Duration] = [.seconds(1), .seconds(5), .seconds(20)]

    /// Nil while push is off (`PUSH_PROVIDER=off`): nothing is read or sent.
    let sender: (any PushSender)?
    let work: BackgroundWork
    let retryDelays: [Duration]

    private enum Result: Sendable {
        case delivered
        case invalid(String)
        case failed
    }

    func notifyNewOrder(_ message: PushMessage, shopID: UUID, store: any PushTokenStore, now: Date, logger: Logger) {
        guard let sender else { return }
        let retryDelays = retryDelays
        work.run {
            let targets: [PushTarget]
            do { targets = try await store.targets(shopID: shopID, now: now) } catch {
                logger.warning("Push recipients not read")
                return
            }
            if targets.isEmpty { return }
            let results = await withTaskGroup(of: Result.self) { group in
                for target in targets {
                    group.addTask { await Self.deliver(message, to: target, with: sender, retryDelays: retryDelays) }
                }
                return await group.reduce(into: [Result]()) { $0.append($1) }
            }
            var removed = 0
            for case .invalid(let token) in results {
                if (try? await store.clear(token: token)) != nil { removed += 1 }
            }
            let sentCount = results.filter { if case .delivered = $0 { true } else { false } }.count
            logger.info("Push sent", metadata: [
                "push_targets": .stringConvertible(targets.count), "push_sent": .stringConvertible(sentCount),
                "push_removed": .stringConvertible(removed),
                "push_failed": .stringConvertible(results.count - sentCount - removed)
            ])
        }
    }

    private static func deliver(
        _ message: PushMessage, to target: PushTarget, with sender: any PushSender, retryDelays: [Duration]
    ) async -> Result {
        for attempt in 0...retryDelays.count {
            do {
                switch try await sender.send(message, to: target) {
                case .delivered: return .delivered
                case .invalidToken: return .invalid(target.token)
                case .rejected: return .failed
                }
            } catch {
                guard attempt < retryDelays.count, (try? await Task.sleep(for: retryDelays[attempt])) != nil else { break }
            }
        }
        return .failed
    }
}
