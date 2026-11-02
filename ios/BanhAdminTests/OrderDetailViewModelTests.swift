import BanhCore
import Foundation
import Testing
@testable import BanhAdmin

@MainActor
struct OrderDetailViewModelTests {
    private func make(_ api: FakeOrdersAPI, changed: @escaping () -> Void = {}) -> OrderDetailViewModel {
        OrderDetailViewModel(code: "BT-7K3M9Q", api: api, onChanged: changed)
    }

    @Test func confirmSendsTheExpectedStatusAndUpdatesInPlace() async {
        let api = FakeOrdersAPI()
        let counter = EndedFlag()
        let model = make(api) { counter.set() }
        await model.load()
        await model.confirm()
        #expect(api.statusCalls.first?.expected == .new)
        #expect(api.statusCalls.first?.target == .confirmed)
        #expect(model.detail?.status == .confirmed)
        #expect(model.toast != nil)
        #expect(counter.value)
    }

    @Test func cancelSendsTheChosenReason() async {
        let api = FakeOrdersAPI()
        api.outcome = .success(.changed(TestData.detail(status: .cancelled)))
        let model = make(api)
        await model.load()
        model.showsCancelSheet = true
        await model.cancel(reason: .fakeSpam)
        #expect(api.statusCalls.first?.reason == .fakeSpam)
        #expect(api.statusCalls.first?.target == .cancelled)
        #expect(!model.showsCancelSheet)
    }

    @Test func conflictShowsTheCurrentStatusAndClosesSheetsAndDialogs() async {
        let api = FakeOrdersAPI()
        api.outcome = .success(.conflict(TestData.detail(status: .confirmed)))
        let model = make(api)
        await model.load()
        model.showsCancelSheet = true
        model.showsCompleteDialog = true
        await model.confirm()
        #expect(model.detail?.status == .confirmed)
        #expect(model.actionMessage == .conflict(.confirmed))
        #expect(!model.showsCancelSheet && !model.showsCompleteDialog)
        #expect(model.toast == nil)
    }

    @Test func offlineActionKeepsTheStatusAndSaysSo() async {
        let api = FakeOrdersAPI()
        api.outcome = .failure(APIError.networkUnavailable)
        let model = make(api)
        await model.load()
        await model.confirm()
        #expect(model.detail?.status == .new)
        #expect(model.actionMessage == .offline)
    }

    @Test func otherFailureShowsTheStatusError() async {
        let api = FakeOrdersAPI()
        api.outcome = .failure(APIError.service(code: "INTERNAL_ERROR", messageKey: "K", httpStatus: 500, details: [:]))
        let model = make(api)
        await model.load()
        await model.complete()
        #expect(model.actionMessage == .failed)
    }

    @Test func unknownOrderIsGoneAndLoadFailureOffersRetry() async {
        let api = FakeOrdersAPI()
        api.detail = .failure(APIError.service(code: "ORDER_NOT_FOUND", messageKey: "K", httpStatus: 404, details: [:]))
        let gone = make(api)
        await gone.load()
        #expect(gone.state == .gone)
        api.detail = .failure(APIError.timeout)
        let failed = make(api)
        await failed.load()
        #expect(failed.state == .failed(.network))
    }
}
