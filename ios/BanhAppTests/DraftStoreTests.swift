import BanhContracts
import XCTest
@testable import BanhApp

/// ADR-0011: the draft is saved on every change, restored, not backed up, and dropped after 24 hours.
@MainActor
final class DraftStoreTests: XCTestCase {
    private let saved = Date(timeIntervalSince1970: 1_793_000_000)
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("draft-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func sampleDraft() -> OrderDraft {
        var draft = OrderDraft(savedAt: saved)
        draft.setQuantity(2, of: OrderTestSupport.id(11), name: "Bánh chuối")
        draft.date = ShopDate(year: 2026, month: 11, day: 4)
        draft.slotID = OrderTestSupport.id(31)
        draft.name = "Nguyễn Văn An"
        draft.phone = "0912345678"
        draft.address = "12 Đường Số 3"
        draft.districtID = OrderTestSupport.id(21)
        draft.note = "Giao buổi sáng"
        return draft
    }

    func testFileStoreRoundTripsEveryField() throws {
        let store = FileDraftStore(url: directory.appendingPathComponent("draft.json"))
        let draft = sampleDraft()
        store.save(draft)
        XCTAssertEqual(store.load(now: saved.addingTimeInterval(60)), draft)
    }

    func testFileIsExcludedFromBackup() throws {
        let url = directory.appendingPathComponent("draft.json")
        FileDraftStore(url: url).save(sampleDraft())
        XCTAssertEqual(try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }

    func testADraftOlderThan24HoursIsDiscardedAndDeleted() throws {
        let url = directory.appendingPathComponent("draft.json")
        let store = FileDraftStore(url: url)
        store.save(sampleDraft())
        XCTAssertNotNil(store.load(now: saved.addingTimeInterval(OrderDraft.lifetime - 1)))
        XCTAssertNil(store.load(now: saved.addingTimeInterval(OrderDraft.lifetime)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testADamagedOrForeignVersionFileIsIgnored() throws {
        let url = directory.appendingPathComponent("draft.json")
        try Data("not json".utf8).write(to: url)
        XCTAssertNil(FileDraftStore(url: url).load(now: saved))

        var future = sampleDraft()
        future.version = OrderDraft.currentVersion + 1
        let store = FileDraftStore(url: url)
        store.save(future)
        XCTAssertNil(store.load(now: saved))
    }

    func testClearRemovesTheDraft() {
        let store = FileDraftStore(url: directory.appendingPathComponent("draft.json"))
        store.save(sampleDraft())
        store.clear()
        XCTAssertNil(store.load(now: saved))
    }

    func testInMemoryStoreExpiresLikeTheFileStore() {
        let store = InMemoryDraftStore(draft: sampleDraft())
        XCTAssertNotNil(store.load(now: saved))
        XCTAssertNil(store.load(now: saved.addingTimeInterval(OrderDraft.lifetime)))
    }

    func testDraftHoldsNoPaymentField() throws {
        // FR-19: nothing payment related is kept anywhere in the draft.
        let json = String(decoding: try JSONEncoder().encode(sampleDraft()), as: UTF8.self).lowercased()
        XCTAssertFalse(json.contains("pay"))
    }
}
