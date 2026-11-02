import Foundation
import BanhContracts

/// Staff accounts of the owner (api/07 10.18; FR-5, BR-6). A staff e-mail
/// address is personal data: it is stored and returned, never logged and
/// never put in `settings_change` or in an error.
struct StaffService: Sendable {
    let store: SettingsStore
    let clock: any WallClock
    let shopID: UUID

    func list() async throws -> StaffList {
        StaffList(accounts: try await store.read { [shopID] queries in try await queries.staff(shopID: shopID) })
    }

    func add(_ body: [String: JSONValue], principal: AdminPrincipal) async throws -> StaffView {
        var form = FormReader(body, allowed: ["name", "email"])
        let name = form.text("name", 1...100)
        var email: String?
        switch body["email"] {
        case .string(let raw)?:
            email = EmailAddress(raw)?.value
            if email == nil { form.add("email", "EMAIL_INVALID", "INVALID") }
        case nil, .null?: form.fail("email", "REQUIRED")
        default: form.add("email", "EMAIL_INVALID", "INVALID")
        }
        try form.finish()
        guard let name, let email else { throw APIError(.validationFailed) }
        let batch = ChangeBatch(shopID: shopID, accountID: principal.accountID, actorName: principal.displayName, at: clock.now())
        let id = UUID()
        return try await store.write { [shopID] writer in
            try await writer.lock(shopID: shopID)
            if try await writer.emailTaken(shopID: shopID, email: email) { throw APIError(.emailTaken) }
            if try await writer.activeStaffCount(shopID: shopID, besides: nil) >= OwnerSettingsService.staffCountMax {
                throw APIError(.staffLimitReached)
            }
            try await writer.insertStaff(shopID: shopID, id: id, name: name, email: email, at: batch.at)
            try await writer.record(batch, entity: "account", id: id, [FieldChange(field: "is_active", old: nil, new: "true")])
            return StaffView(accountID: id, name: name, email: email, role: "staff", isActive: true)
        }
    }

    /// Switches an account off or on. Off ends all its phones at once.
    func setActive(id: UUID, _ body: [String: JSONValue], principal: AdminPrincipal) async throws -> StaffView {
        var form = FormReader(body, allowed: ["is_active"])
        let active = form.bool("is_active")
        try form.finish()
        guard let active else { throw APIError(.validationFailed) }
        let batch = ChangeBatch(shopID: shopID, accountID: principal.accountID, actorName: principal.displayName, at: clock.now())
        return try await store.write { [shopID] writer in
            try await writer.lock(shopID: shopID)
            guard let old = try await writer.queries.staffAccount(shopID: shopID, id: id) else { throw APIError(.notFound) }
            if old.role == "owner" { throw APIError(.ownerProtected) }
            if old.isActive == active { return old }
            if active, try await writer.activeStaffCount(shopID: shopID, besides: id) >= OwnerSettingsService.staffCountMax {
                throw APIError(.staffLimitReached)
            }
            try await writer.setStaffActive(id: id, active, at: batch.at)
            try await writer.record(batch, entity: "account", id: id, [FieldChange(field: "is_active", old: String(old.isActive), new: String(active))])
            return StaffView(accountID: id, name: old.name, email: old.email, role: old.role, isActive: active)
        }
    }
}
