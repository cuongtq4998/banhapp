import Vapor
import Fluent
import FluentSQL

enum ReviewAccountError: Error, Equatable, CustomStringConvertible {
    case unknownAction
    case notConfigured
    case addressTaken
    case shopNotReady
    case noFreeOrderCode

    // Never repeats the address or the code: command output can end up in CI or host logs.
    var description: String {
        switch self {
        case .unknownAction: return "The action must be \"on\" or \"off\""
        case .notConfigured: return "REVIEW_ACCOUNT_EMAIL and REVIEW_ACCOUNT_CODE must both be set"
        case .addressTaken: return "The review address is already a normal account; choose another address"
        case .shopNotReady: return "The shop needs an active district, delivery slot and cake for the demo orders"
        case .noFreeOrderCode: return "No free order code found; run the command again"
        }
    }
}

/// Operator command: `App review-account on|off` (ADR-0027, BR-14).
///
/// `on` creates (or switches on) the staff account of kind `review` and gives
/// it exactly three fake demo orders. `off` removes the demo orders and the
/// account's sessions and switches the account off. Neither touches a real
/// order, a real account or `day_load`. The sign-in itself also needs the two
/// variables on the running server.
struct ReviewAccountCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "action", help: "on or off")
        var action: String
    }

    static let demoOrderCount = 3
    let help = "Switches the store-review account and its three demo orders on or off"
    let config: ReviewCommandConfig

    func run(using context: CommandContext, signature: Signature) async throws {
        let database = context.application.db
        switch signature.action {
        case "on":
            guard let review = try config.review() else { throw ReviewAccountError.notConfigured }
            try await Self.enable(on: database, shopID: config.shopID, review: review, clock: SystemWallClock())
            context.console.print("Review account on with \(Self.demoOrderCount) demo orders.")
        case "off":
            try await Self.disable(on: database, shopID: config.shopID)
            context.console.print("Review account off; demo orders and sessions removed.")
        default:
            throw ReviewAccountError.unknownAction
        }
    }

    /// Idempotent: running `on` again resets the three demo orders.
    static func enable(
        on database: any Database, shopID: UUID, review: ReviewAccountConfig, clock: any WallClock,
        orderCodes: any OrderCodeGenerator = RandomOrderCodeGenerator()
    ) async throws {
        try await inTransaction(database) { store in
            try await store.clear(shopID: shopID)
            guard try await store.enableAccount(shopID: shopID, email: review.email) != nil else { throw ReviewAccountError.addressTaken }
            guard let refs = try await store.references(shopID: shopID) else { throw ReviewAccountError.shopNotReady }
            let calendar = ShopCalendar(clock: clock), today = calendar.today()
            // Two new orders and one confirmed, on the coming days, so every button has something to do.
            let plan: [(days: Int, confirmed: Bool, cakes: Int)] = [(1, false, 2), (2, false, 3), (1, true, 2)]
            for (index, item) in plan.enumerated() {
                var placed = false
                for _ in 0..<10 where !placed {
                    placed = try await store.insertDemoOrder(shopID: shopID, seed: DemoOrderSeed(
                        code: orderCodes.makeCode(), date: calendar.adding(days: item.days, to: today).description,
                        confirmed: item.confirmed, cakes: item.cakes,
                        customerName: "Demo Customer \(index + 1)", customerPhone: "+8490000000\(index + 1)"
                    ), refs: refs)
                }
                guard placed else { throw ReviewAccountError.noFreeOrderCode }
            }
        }
    }

    static func disable(on database: any Database, shopID: UUID) async throws {
        try await inTransaction(database) { try await $0.clear(shopID: shopID) }
    }

    private static func inTransaction(_ database: any Database, _ work: @escaping @Sendable (ReviewAccountStore) async throws -> Void) async throws {
        try await database.transaction { handle in
            guard let sql = handle as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
            try await work(ReviewAccountStore(sql: sql))
        }
    }
}
