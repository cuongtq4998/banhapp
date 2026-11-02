import XCTest
import Logging
@testable import App

final class MailTests: XCTestCase {
    private let message = MailTemplates.signInCode(to: "secret.person@example.com", code: "123456")

    private func dispatcher(_ sender: any EmailSender, work: BackgroundWork) -> MailDispatcher {
        MailDispatcher(sender: sender, work: work, retryDelay: .zero)
    }

    func testConsoleSenderIsRefusedInProductionAndPrintsNoRecipient() async throws {
        XCTAssertThrowsError(try ConsoleEmailSender(stage: .production))
        let printed = LockedBox<[String]>([])
        let console = try ConsoleEmailSender(stage: .local, output: { line in printed.set(printed.value + [line]) })
        try await console.send(message)
        XCTAssertEqual(printed.value.count, 1)
        XCTAssertTrue(printed.value[0].contains("123456"))
        XCTAssertFalse(printed.value[0].contains("secret.person"))
    }

    func testOneRetryThenSuccess() async {
        let sender = RecordingEmailSender(), work = BackgroundWork(), capture = LogCapture()
        sender.failNext(1)
        dispatcher(sender, work: work).sendAfterResponse(message, logger: capture.makeLogger())
        await work.drain()
        XCTAssertEqual(sender.attempts, 2)
        XCTAssertEqual(sender.sent.count, 1)
        XCTAssertTrue(capture.lines.isEmpty)
    }

    func testFailureAfterTheRetryIsLoggedWithoutAddressOrCodeAndIgnored() async {
        let sender = RecordingEmailSender(), work = BackgroundWork(), capture = LogCapture()
        sender.failNext()
        dispatcher(sender, work: work).sendAfterResponse(message, logger: capture.makeLogger())
        await work.drain()
        XCTAssertEqual(sender.attempts, 2)
        XCTAssertTrue(sender.sent.isEmpty)
        XCTAssertEqual(capture.lines.count, 1)
        let text = capture.lines.map { "\($0.message) \($0.metadata)" }.joined()
        XCTAssertFalse(text.contains("secret.person"))
        XCTAssertFalse(text.contains("123456"))
    }

    func testOnSentRunsOnlyAfterSuccess() async {
        let sender = RecordingEmailSender(), work = BackgroundWork(), marked = LockedBox(0)
        dispatcher(sender, work: work).sendAfterResponse(message, logger: Logger(label: "t")) { marked.set(marked.value + 1) }
        await work.drain()
        XCTAssertEqual(marked.value, 1)
    }

    func testNoticeHoldsNoCodeAndShowsShopTime() {
        let notice = MailTemplates.newDeviceNotice(
            to: "owner@example.com", deviceName: "iPhone (iOS 17.5)", at: Date(timeIntervalSince1970: 1_793_577_600)
        )
        XCTAssertEqual(notice.kind, .newDeviceNotice)
        XCTAssertTrue(notice.body.contains("iPhone (iOS 17.5)"))
        XCTAssertTrue(notice.body.contains("02/11/2026 07:00"))
        XCTAssertTrue(notice.body.contains("Đăng xuất các điện thoại khác"))
        XCTAssertNil(notice.body.firstMatch(of: /[0-9]{6}/))
        XCTAssertFalse(notice.body.contains("http"))
    }

    func testRecordingSenderFindsTheCode() async throws {
        let sender = RecordingEmailSender()
        try await sender.send(message)
        XCTAssertEqual(sender.lastCode(to: "secret.person@example.com"), "123456")
        XCTAssertNil(sender.lastCode(to: "other@example.com"))
    }
}
