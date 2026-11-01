#if DEBUG
import Foundation

/// Staff routes of the stub owner backend.
extension StubOwnerBackend {
    func addStaff(_ json: [String: Any]) -> (Int, Data) {
        let name = (json["name"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        let email = (json["email"] as? String)?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        var bad: [(String, String)] = []
        if name.isEmpty { bad.append(("name", "NAME_REQUIRED")) }
        if !email.contains("@") { bad.append(("email", "EMAIL_INVALID")) }
        guard bad.isEmpty else { return validation(bad) }
        if staffList.contains(where: { $0.email.lowercased() == email }) { return StubReply.error(409, "EMAIL_TAKEN", "ERR_EMAIL_TAKEN") }
        if activeStaff >= 30 { return StubReply.error(409, "STAFF_LIMIT_REACHED", "ERR_STAFF_LIMIT") }
        let account = StaffAccount(accountId: newID("000000a0"), name: name, email: email, role: .staff, isActive: true)
        appendStaff(account)
        return StubReply.codable(201, account)
    }

    func patchStaff(_ id: String, _ json: [String: Any]) -> (Int, Data) {
        guard let account = staffList.first(where: { $0.accountId == id }) else { return StubReply.error(404, "NOT_FOUND", "ERR_NOT_FOUND") }
        if account.role == .owner { return StubReply.error(409, "OWNER_PROTECTED", "ERR_SERVER") }
        guard let active = json["is_active"] as? Bool else { return validation([("is_active", "IS_ACTIVE_REQUIRED")]) }
        if active, !account.isActive, activeStaff >= 30 { return StubReply.error(409, "STAFF_LIMIT_REACHED", "ERR_STAFF_LIMIT") }
        let changed = StaffAccount(accountId: id, name: account.name, email: account.email, role: .staff, isActive: active)
        replaceStaff(changed)
        return StubReply.codable(200, changed)
    }

    private var activeStaff: Int { staffList.filter { $0.role == .staff && $0.isActive }.count }
}
#endif
