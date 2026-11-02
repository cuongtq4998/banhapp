import BanhCore
import Foundation
import Testing
@testable import BanhAdmin

@MainActor
struct OrderDetailViewModelTests {
    private func make(_ api: FakeOrdersAPI, changed: @escaping () -> Void = {}) -> OrderDetailViewModel {
        OrderDetailViewModel(code: "BT-7K3M9Q", api: api, onChanged: changed)
    }

    @Test func processSendsTheExpectedStatusAndUpdatesInPlace() async {
        let api = FakeOrdersAPI()
        let counter = EndedFlag()
        let model = make(api) { counter.set() }
        await model.load()
        await model.process()
        #expect(api.statusCalls.first?.expected == .received)
        #expect(api.statusCalls.first?.target == .processing)
        #expect(model.detail?.status == .processing)
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
        api.outcome = .success(.conflict(TestData.detail(status: .processing)))
        let model = make(api)
        await model.load()
        model.showsCancelSheet = true
        model.showsFinishDialog = true
        await model.process()
        #expect(model.detail?.status == .processing)
        #expect(model.actionMessage == .conflict(.processing))
        #expect(!model.showsCancelSheet && !model.showsFinishDialog)
        #expect(model.toast == nil)
    }

    @Test func offlineActionKeepsTheStatusAndSaysSo() async {
        let api = FakeOrdersAPI()
        api.outcome = .failure(APIError.networkUnavailable)
        let model = make(api)
        await model.load()
        await model.process()
        #expect(model.detail?.status == .received)
        #expect(model.actionMessage == .offline)
    }

    @Test func otherFailureShowsTheStatusError() async {
        let api = FakeOrdersAPI()
        api.outcome = .failure(APIError.service(code: "INTERNAL_ERROR", messageKey: "K", httpStatus: 500, details: [:]))
        let model = make(api)
        await model.load()
        await model.finish()
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
