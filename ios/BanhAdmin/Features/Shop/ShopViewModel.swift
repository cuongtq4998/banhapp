import BanhCore
import Foundation
import Observation

/// S-A11 Shop info: name, greeting, contact phone, Zalo (FR-24, BR-11).
@Observable
final class ShopViewModel {
    private(set) var load: Load<ShopInfo> = .loading
    var name = ""
    var greeting = ""
    var phone = ""
    var zalo = ""
    private(set) var errors: [String: String] = [:]
    var banner: String?
    var focusRequest: String?
    var showsDiscard = false
    private(set) var isBusy = false
    private var original: ShopInfo?
    private let api: any OwnerAPI
    private let flash: (String) -> Void
    private let done: () -> Void

    init(api: any OwnerAPI, flash: @escaping (String) -> Void, done: @escaping () -> Void) {
        self.api = api
        self.flash = flash
        self.done = done
    }

    func loadShop() async {
        do {
            let shop = try await api.settings().shop
            original = shop
            name = shop.name
            greeting = shop.greeting
            phone = shop.phoneContact
            zalo = shop.zaloContact
            load = .ready(shop)
        } catch {
            if !(error is SessionEnded) { load = .failed(error.loadFailure) }
        }
    }

    func retryLoad() async {
        load = .loading
        await loadShop()
    }

    private var current: ShopInfo {
        ShopInfo(
            name: FieldRules.trimmed(name), greeting: FieldRules.trimmed(greeting),
            phoneContact: FieldRules.e164(FieldRules.trimmed(phone)) ?? FieldRules.trimmed(phone), zaloContact: FieldRules.trimmed(zalo)
        )
    }

    var isDirty: Bool { original.map { current != $0 } ?? false }
    var canSave: Bool { isDirty && !isBusy }

    @discardableResult
    func validate() -> Bool {
        var found: [String: String] = [:]
        if let text = FieldRules.text(name, AStrings.fShopName, max: 100) { found["name"] = text }
        if let text = FieldRules.text(greeting, AStrings.fGreeting, max: 300) { found["greeting"] = text }
        if let text = FieldRules.phone(phone, AStrings.fPhone) { found["phone_contact"] = text }
        if let text = FieldRules.text(zalo, AStrings.fZalo, max: 100, min: 3) { found["zalo_contact"] = text }
        errors = found
        let order = [("name", AdminOwnerID.shopName), ("greeting", AdminOwnerID.shopGreeting), ("phone_contact", AdminOwnerID.shopPhone), ("zalo_contact", AdminOwnerID.shopZalo)]
        focusRequest = order.first { found[$0.0] != nil }?.1
        return found.isEmpty
    }

    func save() async {
        banner = nil
        guard validate() else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await api.saveShop(current)
            flash(String(localized: AStrings.saved))
            done()
        } catch {
            fail(error)
        }
    }

    private func fail(_ error: Error) {
        guard !(error is SessionEnded) else { return }
        guard let failure = error as? APIError, failure.code == "VALIDATION_FAILED", !failure.fieldProblems.isEmpty else {
            return banner = error.saveMessage
        }
        var found: [String: String] = [:]
        for problem in failure.fieldProblems {
            switch problem.field {
            case "name": found["name"] = FieldRules.server(problem, AStrings.fShopName, max: 100)
            case "greeting": found["greeting"] = FieldRules.server(problem, AStrings.fGreeting, max: 300)
            case "phone_contact": found["phone_contact"] = AStrings.errPhone(AStrings.fPhone)
            case "zalo_contact": found["zalo_contact"] = FieldRules.server(problem, AStrings.fZalo, max: 100)
            default: banner = String(localized: AStrings.errGeneric)
            }
        }
        errors = found
    }
}
