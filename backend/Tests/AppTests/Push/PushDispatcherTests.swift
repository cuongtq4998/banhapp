import XCTest
import Logging
@testable import App

/// The dispatcher over a fake store: retries, dead tokens, logging, off.
final class PushDispatcherTests: XCTestCase {
    private final class FakeStore: PushTokenStore, @unchecked Sendable {
        let targets: [PushTarget]
        let cleared = LockedBox<[String]>([])
        let readFails: Bool
        init(_ targets: [PushTarget], readFails: Bool = false) { self.targets = targets; self.readFails = readFails }
        func targets(shopID: UUID, now: Date) async throws -> [PushTarget] {
            if readFails { throw PushSenderUnavailable() }
            return targets
        }
        func clear(token: String) async throws { cleared.set(cleared.value + [token]) }
    }

    private let work = BackgroundWork()
    private let capture = LogCapture()
    private let phones = [PushTestData.ios, PushTestData.android]

    private func dispatcher(_ sender: (any PushSender)?, delays: [Duration] = [.zero, .zero, .zero]) -> PushDispatcher {
        PushDispatcher(sender: sender, work: work, retryDelays: delays)
    }

    private func notify(_ dispatcher: PushDispatcher, _ store: FakeStore) async {
        dispatcher.notifyNewOrder(PushTestData.message, shopID: UUID(), store: store, now: PushTestData.now, logger: capture.makeLogger())
        await work.drain()
    }

    func testEveryTargetGetsOnePush() async {
        let sender = RecordingPushSender()
        await notify(dispatcher(sender), FakeStore(phones))
        XCTAssertEqual(Set(sender.tokens), [PushTestData.ios.token, PushTestData.android.token])
        XCTAssertEqual(sender.attempts, 2)
    }

    func testRetriesThreeTimesThenGivesUpWithoutDeletingTheToken() async {
        let sender = RecordingPushSender(), store = FakeStore([PushTestData.android])
        sender.failNext()
        await notify(dispatcher(sender), store)
        XCTAssertEqual(sender.attempts, 4, "first try and retries after 1, 5 and 20 s")
        XCTAssertTrue(sender.sent.isEmpty)
        XCTAssertEqual(store.cleared.value, [])
    }

    func testARetryCanSucceed() async {
        let sender = RecordingPushSender()
        sender.failNext(2)
        await notify(dispatcher(sender), FakeStore([PushTestData.android]))
        XCTAssertEqual(sender.attempts, 3)
        XCTAssertEqual(sender.sent.count, 1)
    }

    func testRetryDelaysAreTheDocumentedOnes() {
        XCTAssertEqual(PushDispatcher.defaultRetryDelays, [.seconds(1), .seconds(5), .seconds(20)])
    }

    func testDeadTokenIsDeletedAndNotRetried() async {
        let sender = RecordingPushSender(), store = FakeStore(phones)
        sender.markDead(PushTestData.ios.token)
        await notify(dispatcher(sender), store)
        XCTAssertEqual(store.cleared.value, [PushTestData.ios.token])
        XCTAssertEqual(sender.attempts, 2)
        XCTAssertEqual(sender.tokens, [PushTestData.android.token])
    }

    func testOneLogLineWithCountsOnly() async {
        let sender = RecordingPushSender()
        sender.markDead(PushTestData.ios.token)
        await notify(dispatcher(sender), FakeStore(phones))
        XCTAssertEqual(capture.lines.count, 1)
        let line = capture.lines[0]
        XCTAssertEqual(line.metadata["push_targets"]?.description, "2")
        XCTAssertEqual(line.metadata["push_sent"]?.description, "1")
        XCTAssertEqual(line.metadata["push_removed"]?.description, "1")
        XCTAssertEqual(line.metadata["push_failed"]?.description, "0")
        let text = "\(line.message) \(line.metadata)"
        for secret in [PushTestData.ios.token, PushTestData.android.token, PushTestData.message.orderCode] {
            XCTAssertFalse(text.contains(secret))
        }
    }

    func testNoTargetsMeansNoSendAndNoLog() async {
        let sender = RecordingPushSender()
        await notify(dispatcher(sender), FakeStore([]))
        XCTAssertEqual(sender.attempts, 0)
        XCTAssertTrue(capture.lines.isEmpty)
    }

    func testStoreFailureIsLoggedAndSwallowed() async {
        let sender = RecordingPushSender()
        await notify(dispatcher(sender), FakeStore(phones, readFails: true))
        XCTAssertEqual(sender.attempts, 0)
        XCTAssertEqual(capture.lines.count, 1)
    }

    func testOffReadsNothing() async {
        let store = FakeStore(phones)
        await notify(dispatcher(nil), store)
        XCTAssertTrue(capture.lines.isEmpty)
    }

    func testMessageTextIsCodeCakesAndDateOnly() {
        XCTAssertEqual(PushTestData.message.bodyArguments, ["BT-7K3M9Q", "3", "05/11/2026"])
    }
}
