import BanhCore
import Foundation
import Testing
@testable import BanhAdmin

@MainActor
struct OwnerSettingsViewModelTests {
    // MARK: S-A9 Ordering

    private func rules(_ api: FakeOwnerAPI, _ sink: Sink = Sink()) -> RulesViewModel {
        RulesViewModel(api: api, flash: sink.flash, done: sink.done)
    }

    @Test func rangesAndMinimumAboveLimitAreCheckedOnThePair() async {
        let model = rules(FakeOwnerAPI())
        await model.loadRules()
        model.limit = "0"; model.lead = "15"; model.minimum = "21"
        #expect(!model.validate())
        #expect(Set(model.errors.keys) == ["daily_limit", "lead_days", "min_qty"])
        model.limit = "3"; model.lead = "2"; model.minimum = "5"
        #expect(!model.validate())
        #expect(model.errors["min_qty"] == AStrings.errMinAboveLimit(AStrings.fMin))
        #expect(model.focusRequest == AdminOwnerID.rulesMin)
    }

    @Test func loweringBelowAcceptedCakesAsksFirstThenSavesAnyway() async {
        let api = FakeOwnerAPI()
        let list = [OverLimitDate(date: "2026-11-05", cakesAccepted: 98)]
        api.impactResult = .success(OrderingImpact(dailyLimit: 40, overLimit: list, count: 1))
        api.savedOrdering = .success(TestOwner.saved(list))
        let sink = Sink()
        let model = rules(api, sink)
        await model.loadRules()
        model.limit = "40"
        await model.save()
        #expect(model.warning == list)
        #expect(!api.calls.contains { $0.hasPrefix("PUT") }, "nothing saved before the owner agrees")
        await model.confirmWarning()
        #expect(api.calls.last == "PUT ordering 40 2 2")
        #expect(model.result == nil, "the same list is not shown twice")
        #expect(sink.doneCount == 1)
    }

    @Test func listReturnedBySaveThatDiffersFromThePreviewIsShown() async {
        let api = FakeOwnerAPI()
        api.savedOrdering = .success(TestOwner.saved([OverLimitDate(date: "2026-11-07", cakesAccepted: 55)]))
        let sink = Sink()
        let model = rules(api, sink)
        await model.loadRules()
        model.limit = "40"
        await model.save()
        #expect(model.result?.first?.date == "2026-11-07")
        #expect(sink.doneCount == 0)
        model.closeResult()
        #expect(sink.doneCount == 1)
    }

    @Test func raisingTheLimitDoesNotAskTheServerFirst() async {
        let api = FakeOwnerAPI()
        let model = rules(api)
        await model.loadRules()
        model.limit = "80"
        await model.save()
        #expect(!api.calls.contains { $0.hasPrefix("GET impact") })
    }

    // MARK: S-A11 Shop

    @Test func shopValidatesPhoneAndSendsE164() async {
        let api = FakeOwnerAPI()
        let sink = Sink()
        let model = ShopViewModel(api: api, flash: sink.flash, done: sink.done)
        await model.loadShop()
        #expect(!model.canSave)
        model.phone = "12345"; model.zalo = "ab"; model.name = " "
        #expect(!model.validate())
        #expect(Set(model.errors.keys) == ["name", "phone_contact", "zalo_contact"])
        model.name = "Tiem"; model.phone = "0900 111 222"; model.zalo = "zalo.me/x"
        await model.save()
        #expect(api.lastShop?.phoneContact == "+84900111222")
        #expect(sink.doneCount == 1 && sink.toasts == [String(localized: AStrings.saved)])
    }

    @Test func shopServerValidationAndOfflineKeepValues() async {
        let api = FakeOwnerAPI()
        let model = ShopViewModel(api: api, flash: { _ in }, done: {})
        await model.loadShop()
        model.greeting = "Chao"
        api.writeError = TestOwner.problem(422, "VALIDATION_FAILED", fields: [FieldProblem(field: "phone_contact", code: "PHONE_CONTACT_INVALID")])
        await model.save()
        #expect(model.errors["phone_contact"] != nil && model.greeting == "Chao")
        api.writeError = APIError.networkUnavailable
        await model.save()
        #expect(model.banner == String(localized: AStrings.offlineSave))
    }

    // MARK: S-A10 Delivery

    @Test func switchOffTheLastDistrictShowsTheRuleAndKeepsTheRow() async {
        let api = FakeOwnerAPI()
        let sink = Sink()
        let model = DeliveryViewModel(api: api, flash: sink.flash)
        await model.reload()
        api.writeError = TestOwner.problem(409, "LAST_ACTIVE_DISTRICT")
        await model.setDistrict(model.districts[0], active: false)
        #expect(sink.toasts == [String(localized: AStrings.errLastDistrict)])
        #expect(model.districts[0].isActive)
        api.writeError = TestOwner.problem(409, "LAST_ACTIVE_SLOT")
        await model.setSlot(model.slots[0], active: false)
        #expect(sink.toasts.last == String(localized: AStrings.errLastSlot))
    }

    @Test func districtSheetChecksRangeAndMapsDuplicateName() async {
        let api = FakeOwnerAPI()
        let model = DistrictEditorModel(existing: nil, api: api, onSaved: {})
        model.name = ""; model.fee = "0"
        await model.save()
        #expect(Set(model.errors.keys) == ["name", "delivery_fee_vnd"] && api.calls.isEmpty)
        model.name = "Quan 1"; model.fee = "20.000"
        api.writeError = TestOwner.problem(422, "VALIDATION_FAILED", fields: [FieldProblem(field: "name", code: "NAME_TAKEN")])
        await model.save()
        #expect(model.errors["name"] == String(localized: AStrings.errDistrictDup))
    }

    @Test func slotSheetNeedsStartBeforeEndAndMapsDuplicate() async {
        let api = FakeOwnerAPI()
        var saved = 0
        let model = SlotEditorModel(existing: nil, api: api, onSaved: { saved += 1 })
        model.start = 600; model.end = 600
        await model.save()
        #expect(model.error == String(localized: AStrings.errSlotOrder) && api.calls.isEmpty)
        model.end = 660
        await model.save()
        #expect(api.calls == ["POST slot 10:00 11:00"] && saved == 1)
        api.writeError = TestOwner.problem(422, "SLOT_DUPLICATE")
        await model.save()
        #expect(model.error == String(localized: AStrings.errSlotDup))
    }
}
