import BanhCore
import Foundation
import Testing
@testable import BanhAdmin

@MainActor
struct OwnerStaffViewModelTests {
    // MARK: S-A12 Staff

    @Test func staffAddMapsEmailTakenAndLimit() async {
        let api = FakeOwnerAPI()
        let model = StaffAddModel(api: api, onAdded: {})
        model.name = "B"; model.email = "bad"
        await model.save()
        #expect(model.errors["email"] == String(localized: AStrings.errEmailInvalid) && api.calls.isEmpty)
        model.email = "b@example.com"
        api.writeError = TestOwner.problem(409, "EMAIL_TAKEN")
        await model.save()
        #expect(model.errors["email"] == String(localized: AStrings.errEmailTaken))
        api.writeError = TestOwner.problem(409, "STAFF_LIMIT_REACHED")
        await model.save()
        #expect(model.banner == String(localized: AStrings.errStaffFull))
    }

    @Test func staffListCountsActiveStaffOnlyAndOwnerCannotBeOpened() async {
        let sink = Sink()
        let model = StaffViewModel(api: FakeOwnerAPI(), flash: sink.flash)
        await model.reload()
        #expect(model.activeStaff == 1 && !model.isFull)
        model.open(model.accounts[0])
        #expect(model.selected == nil)
        model.open(model.accounts[1])
        #expect(model.selected?.accountId == "a2")
    }

    @Test func deactivateReactivateAndOwnerProtected() async {
        let api = FakeOwnerAPI()
        let sink = Sink()
        let model = StaffViewModel(api: api, flash: sink.flash)
        await model.reload()
        model.open(model.accounts[1])
        await model.deactivate()
        #expect(api.calls.last == "PATCH staff a2 false" && model.selected == nil)
        model.open(model.accounts[1])
        api.writeError = TestOwner.problem(409, "OWNER_PROTECTED")
        await model.reactivate()
        #expect(model.detailMessage == String(localized: AStrings.errGeneric))
        api.writeError = TestOwner.problem(409, "STAFF_LIMIT_REACHED")
        await model.reactivate()
        #expect(model.detailMessage == String(localized: AStrings.errStaffFull))
    }

    // MARK: S-A6 / S-A7

    @Test func overviewRowValuesAndDashOnFailure() async {
        let api = FakeOwnerAPI()
        let model = SettingsOverviewModel(api: api)
        await model.load()
        #expect(model.cakesValue == "2/12" && model.staffValue == "1/30" && model.shopValue == "Tiem Banh Mau")
        let failing = FakeOwnerAPI()
        failing.settingsResult = .failure(APIError.networkUnavailable)
        let down = SettingsOverviewModel(api: failing)
        await down.load()
        #expect(down.cakesValue == "–" && down.rulesValue == "–")
    }

    @Test func cakesListShowsActiveFirstThenHiddenByName() async {
        let api = FakeOwnerAPI()
        api.settingsResult = .success(TestOwner.settings(cakes: [
            TestOwner.cake("1", "Zed", active: false), TestOwner.cake("2", "Beta"), TestOwner.cake("3", "alpha"),
        ]))
        let model = CakesViewModel(api: api)
        await model.reload()
        #expect(model.cakes.map(\.name) == ["alpha", "Beta", "Zed"])
        #expect(!model.isFull)
    }
}
