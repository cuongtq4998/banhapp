import BanhCore
import Foundation
import Observation

/// S-A12 Staff: accounts, add, switch off and on (FR-5, BR-6). The owner row cannot be changed.
@Observable
final class StaffViewModel {
    static let limit = 30
    private(set) var load: Load<[StaffAccount]> = .loading
    var adder: StaffAddModel?
    var selectedID: String?
    var showsDeactivate = false
    var detailMessage: String?
    private(set) var isBusy = false
    private let api: any OwnerAPI
    private let flash: (String) -> Void

    init(api: any OwnerAPI, flash: @escaping (String) -> Void) {
        self.api = api
        self.flash = flash
    }

    var accounts: [StaffAccount] { load.value ?? [] }
    var activeStaff: Int { accounts.filter { $0.role == .staff && $0.isActive }.count }
    var isFull: Bool { activeStaff >= Self.limit }
    var selected: StaffAccount? { accounts.first { $0.accountId == selectedID } }
    var onlyOwner: Bool { load.value != nil && !accounts.contains { $0.role == .staff } }

    func reload() async {
        do { load = .ready(try await api.staff()) } catch {
            if !(error is SessionEnded), load.value == nil { load = .failed(error.loadFailure) }
        }
    }

    func retry() async {
        load = .loading
        await reload()
    }

    func add() { adder = StaffAddModel(api: api) { [weak self] in self?.added() } }

    private func added() {
        adder = nil
        flash(String(localized: AStrings.staffAdded))
        Task { await reload() }
    }

    func open(_ account: StaffAccount) {
        guard account.role == .staff else { return }
        detailMessage = nil
        selectedID = account.accountId
    }

    func deactivate() async { await setActive(false) }
    func reactivate() async { await setActive(true) }

    private func setActive(_ active: Bool) async {
        guard let id = selectedID else { return }
        showsDeactivate = false
        detailMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await api.setStaffActive(id: id, active: active)
            selectedID = nil
            flash(String(localized: AStrings.saved))
            await reload()
        } catch {
            guard !(error is SessionEnded) else { return }
            switch (error as? APIError)?.code {
            case "STAFF_LIMIT_REACHED": detailMessage = String(localized: AStrings.errStaffFull)
            case "OWNER_PROTECTED": detailMessage = String(localized: AStrings.errGeneric)
            default: detailMessage = error.saveMessage
            }
        }
    }
}

/// The add sheet: name and e-mail, both required.
@Observable
final class StaffAddModel: Identifiable {
    var name = ""
    var email = ""
    private(set) var errors: [String: String] = [:]
    var banner: String?
    var focusRequest: String?
    private(set) var isBusy = false
    private let api: any OwnerAPI
    private let onAdded: () -> Void

    init(api: any OwnerAPI, onAdded: @escaping () -> Void) {
        self.api = api
        self.onAdded = onAdded
    }

    var canSave: Bool { !isBusy && ![name, email].contains { FieldRules.trimmed($0).isEmpty } }

    @discardableResult
    func validate() -> Bool {
        var found: [String: String] = [:]
        if let text = FieldRules.text(name, AStrings.fStaffName, max: 100) { found["name"] = text }
        if !EmailViewModel.isValid(FieldRules.trimmed(email)) { found["email"] = String(localized: AStrings.errEmailInvalid) }
        errors = found
        focusRequest = found["name"] != nil ? AdminOwnerID.staffAddName : (found["email"] != nil ? AdminOwnerID.staffAddEmail : nil)
        return found.isEmpty
    }

    func save() async {
        banner = nil
        guard validate() else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await api.addStaff(name: FieldRules.trimmed(name), email: FieldRules.trimmed(email))
            onAdded()
        } catch {
            guard !(error is SessionEnded) else { return }
            switch (error as? APIError)?.code {
            case "EMAIL_TAKEN": errors = ["email": String(localized: AStrings.errEmailTaken)]
            case "STAFF_LIMIT_REACHED": banner = String(localized: AStrings.errStaffFull)
            case "VALIDATION_FAILED":
                let problems = (error as? APIError)?.fieldProblems ?? []
                var found: [String: String] = [:]
                for problem in problems {
                    if problem.field == "email" { found["email"] = String(localized: AStrings.errEmailInvalid) }
                    if problem.field == "name" { found["name"] = FieldRules.server(problem, AStrings.fStaffName, max: 100) }
                }
                errors = found
                if found.isEmpty { banner = String(localized: AStrings.errGeneric) }
            default: banner = error.saveMessage
            }
        }
    }
}
