import Vapor
import Fluent
import FluentSQL

enum CreateOwnerError: Error, Equatable, CustomStringConvertible {
    case emailInvalid
    case nameInvalid
    case alreadyExists

    // Never repeats the address: command output can end up in CI or host logs.
    var description: String {
        switch self {
        case .emailInvalid: return "--email is missing or not a valid address"
        case .nameInvalid: return "--name must be 1 to 100 characters"
        case .alreadyExists: return "This shop already has an owner, or the address is already an account"
        }
    }
}

/// Operator command: `App create-owner --email <address> [--name <name>]`.
/// Creates the one owner account of the shop (A-2). Staff are added by the
/// owner in the app.
struct CreateOwnerCommand: AsyncCommand {
    static let defaultName = "Owner"

    struct Signature: CommandSignature {
        @Option(name: "email", help: "Sign-in address of the owner")
        var email: String?
        @Option(name: "name", help: "Display name, default \"Owner\"")
        var name: String?
    }

    let help = "Creates the owner account of the shop (SHOP_ID)"
    let shopID: UUID

    func run(using context: CommandContext, signature: Signature) async throws {
        try await Self.create(on: context.application.db, shopID: shopID, email: signature.email ?? "", name: signature.name)
        context.console.print("Owner account created.")
    }

    static func create(on database: any Database, shopID: UUID, email rawEmail: String, name: String?) async throws {
        guard let email = EmailAddress(rawEmail) else { throw CreateOwnerError.emailInvalid }
        let displayName = (name ?? defaultName).trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...100).contains(displayName.unicodeScalars.count) else { throw CreateOwnerError.nameInvalid }
        guard let sql = database as? any SQLDatabase else { throw CatalogRepositoryError.sqlNotSupported }
        let taken = try await sql.raw("""
            SELECT 1 AS found FROM account
             WHERE shop_id = \(bind: shopID) AND (role = 'owner' OR email = \(bind: email.value)) LIMIT 1
            """).first()
        guard taken == nil else { throw CreateOwnerError.alreadyExists }
        try await sql.raw("""
            INSERT INTO account (shop_id, role, email, display_name)
            VALUES (\(bind: shopID), 'owner', \(bind: email.value), \(bind: displayName))
            """).run()
    }
}
