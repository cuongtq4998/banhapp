import BanhContracts
import BanhCore
import Foundation
import Testing
import UIKit
@testable import BanhAdmin

@MainActor
struct CakeFormViewModelTests {
    private func add(_ api: FakeOwnerAPI = FakeOwnerAPI(), _ sink: Sink = Sink()) -> CakeFormViewModel {
        CakeFormViewModel(mode: .add, api: api, flash: sink.flash, done: sink.done)
    }

    private func edit(_ api: FakeOwnerAPI, _ sink: Sink = Sink(), id: String = "c1") -> CakeFormViewModel {
        CakeFormViewModel(mode: .edit(id), api: api, flash: sink.flash, done: sink.done)
    }

    private func fill(_ model: CakeFormViewModel) async {
        model.name = "Banh Moi"
        model.description = "Mo ta"
        model.price = "150.000"
        await model.pick(DebugPickButton.photo(side: 3000))
    }

    @Test func addSaveIsEnabledOnceAnythingIsTypedAndNeverBecauseOfAnInvalidField() async {
        let model = add()
        #expect(!model.canSave)
        model.name = "A"
        #expect(model.canSave, "enabled although the other fields and the picture are missing")
        model.name = ""
        #expect(!model.canSave)
        await model.pick(DebugPickButton.photo(side: 1000))
        #expect(model.canSave)
    }

    @Test func pictureSizeProblemsHaveTheirOwnMessageAndComeBackOnSave() async {
        let model = add()
        await model.pick(DebugPickButton.photo(side: 150))
        #expect(model.errors["image"] == String(localized: AStrings.errImgDimSmall))
        await model.pick(DebugPickButton.photo(side: 4200))
        #expect(model.errors["image"] == String(localized: AStrings.errImgDimLarge))
        await model.save()
        #expect(model.errors["image"] == String(localized: AStrings.errImgDimLarge), "Save shows the refused picture's message again")
        await model.pick(DebugPickButton.photo(side: 1000))
        #expect(model.errors["image"] == nil && model.pickedJPEG != nil)
    }

    @Test func pickedPictureIsReEncodedAsJpegWithinTheLimits() async throws {
        let model = add()
        await model.pick(DebugPickButton.photo(side: 3000))
        let jpeg = try #require(model.pickedJPEG)
        #expect(jpeg.starts(with: [0xFF, 0xD8, 0xFF]))
        #expect(jpeg.count <= 5_242_880)
        let image = try #require(UIImage(data: jpeg))
        #expect(max(image.size.width, image.size.height) <= 1600 && min(image.size.width, image.size.height) >= 200)
    }

    @Test func brokenPictureIsRefusedAndNotKept() async {
        let model = add()
        await model.pick(Data("nope".utf8))
        #expect(model.pickedJPEG == nil)
        #expect(model.errors["image"] == String(localized: AStrings.errImgRead))
        await model.pick(nil)
        #expect(model.errors["image"] == String(localized: AStrings.errImgRead))
    }

    @Test func saveShowsEveryErrorAtOnceAndFocusesTheFirst() async {
        let api = FakeOwnerAPI()
        let model = add(api)
        await model.save()
        #expect(Set(model.errors.keys) == ["name", "description", "price_vnd", "image"])
        #expect(model.focusRequest == AdminOwnerID.cakeName)
        #expect(api.calls.isEmpty, "nothing is sent when a field fails")
    }

    @Test func successfulAddUploadsOneRequestThenToastsAndGoesBack() async {
        let api = FakeOwnerAPI()
        let sink = Sink()
        let model = add(api, sink)
        await fill(model)
        await model.save()
        #expect(api.calls == ["POST cake Banh Moi 150000"])
        #expect(api.lastJPEG != nil)
        #expect(sink.toasts == [String(localized: AStrings.cakeAdded)])
        #expect(sink.doneCount == 1)
    }

    @Test func serverRefusalsMapToTheirMessages() async {
        let cases: [(APIError, String?, String?)] = [
            (TestOwner.problem(422, "VALIDATION_FAILED", fields: [FieldProblem(field: "name", code: "NAME_TAKEN")]), "name", String(localized: AStrings.errCakeNameDup)),
            (TestOwner.problem(409, "CAKE_LIMIT_REACHED"), nil, String(localized: AStrings.errCakesFull)),
            (TestOwner.problem(413, "IMAGE_TOO_LARGE"), "image", String(localized: AStrings.errImgSize)),
            (APIError.networkUnavailable, nil, String(localized: AStrings.offlineSave)),
            (TestOwner.problem(500, "INTERNAL_ERROR"), nil, String(localized: AStrings.errUpload)),
        ]
        for (error, field, text) in cases {
            let api = FakeOwnerAPI()
            api.writeError = error
            let sink = Sink()
            let model = add(api, sink)
            await fill(model)
            await model.save()
            #expect(sink.doneCount == 0, "values and picture stay")
            #expect(model.pickedJPEG != nil && model.name == "Banh Moi")
            if let field { #expect(model.errors[field] == text) } else { #expect(model.banner == text) }
        }
    }

    @Test func editSavesOnlyChangedFields() async {
        let api = FakeOwnerAPI()
        let model = edit(api)
        await model.loadCake()
        #expect(!model.canSave)
        model.price = "160.000"
        #expect(model.canSave)
        await model.save()
        #expect(api.lastChanges == ["price_vnd": .int(160_000)])
    }

    @Test func hidingTheOnlyActiveCakeIsRefusedAtOnce() async {
        let api = FakeOwnerAPI()
        api.settingsResult = .success(TestOwner.settings(cakes: [TestOwner.cake("c1", "Banh Mau")]))
        let sink = Sink()
        let model = edit(api, sink)
        await model.loadCake()
        model.setActive(false)
        #expect(model.isActive)
        #expect(sink.toasts == [String(localized: AStrings.errLastCake)])
        model.requestRemove()
        #expect(!model.showsRemoveDialog)
    }

    @Test func lastActiveCakeFromTheServerResetsTheSwitch() async {
        let api = FakeOwnerAPI()
        let sink = Sink()
        let model = edit(api, sink)
        await model.loadCake()
        model.setActive(false)
        api.writeError = TestOwner.problem(409, "LAST_ACTIVE_CAKE")
        await model.save()
        #expect(model.isActive)
        #expect(sink.toasts.last == String(localized: AStrings.errLastCake))
    }

    @Test func removeAsksThenDeletes() async {
        let api = FakeOwnerAPI()
        api.settingsResult = .success(TestOwner.settings(cakes: [TestOwner.cake("c1", "Banh Mau"), TestOwner.cake("c2", "Banh Chuoi")]))
        let sink = Sink()
        let model = edit(api, sink)
        await model.loadCake()
        model.requestRemove()
        #expect(model.showsRemoveDialog)
        await model.confirmRemove()
        #expect(api.calls.last == "DELETE cake c1")
        #expect(sink.toasts == [String(localized: AStrings.cakeRemoved)] && sink.doneCount == 1)
    }

    @Test func cakeRemovedElsewhereShowsTheGoneState() async {
        let model = edit(FakeOwnerAPI(), id: "missing")
        await model.loadCake()
        #expect(model.isGone)
    }

    @Test func leavingWithAnyValueIsDirty() {
        let model = add()
        #expect(!model.isDirty)
        model.name = "x"
        #expect(model.isDirty)
    }

    @Test func cancelStopsTheUploadAndCreatesNothing() async {
        let api = FakeOwnerAPI()
        let sink = Sink()
        let model = add(api, sink)
        await fill(model)
        model.startSave()
        model.cancelUpload()
        try? await Task.sleep(for: .milliseconds(200))
        #expect(sink.doneCount == 0 && sink.toasts.isEmpty)
        #expect(!model.isBusy)
    }
}
