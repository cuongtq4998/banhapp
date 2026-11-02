import XCTVapor
import FluentSQL
@testable import App

/// Districts and slots (api/07 10.16; FR-23, BR-3, BR-11).
final class OwnerDistrictSlotTests: OwnerSettingsTestCase {
    func testAddingADistrictReturns201AndRecordsIt() async throws {
        let reply = try await call(.POST, "v1/owner/districts", #"{"name":" Quan 1 ","delivery_fee_vnd":35000}"#)
        XCTAssertEqual(reply.status, .created)
        XCTAssertEqual(reply.json["name"] as? String, "Quan 1")
        XCTAssertEqual(reply.json["is_active"] as? Bool, true)
        XCTAssertNotNil(UUID(uuidString: reply.string("district_id")))
        let catalog = try await send(.GET, "v1/catalog")
        XCTAssertEqual((catalog.json["districts"] as? [[String: Any]])?.count, 2)
        let fee = try await changeCount(field: "delivery_fee_vnd", old: nil, new: "35000")
        XCTAssertEqual(fee, 1)
    }

    func testDistrictValidationListsEveryProblemAndNameIsUnique() async throws {
        let bad = try await call(.POST, "v1/owner/districts", #"{"name":"","delivery_fee_vnd":10000001}"#)
        XCTAssertEqual(problems(bad), ["NAME_REQUIRED", "DELIVERY_FEE_VND_OUT_OF_RANGE"])
        let zero = try await call(.POST, "v1/owner/districts", #"{"name":"X","delivery_fee_vnd":0}"#)
        XCTAssertEqual(problems(zero), ["DELIVERY_FEE_VND_OUT_OF_RANGE"])
        let twin = try await call(.POST, "v1/owner/districts", #"{"name":"quan an phu","delivery_fee_vnd":1}"#)
        XCTAssertEqual(twin.status, .unprocessableEntity)
        XCTAssertEqual(problems(twin), ["NAME_TAKEN"])
        let rows = try await changeRows("district")
        XCTAssertEqual(rows, 0)
    }

    func testChangingADistrictLeavesEarlierOrdersAlone() async throws {
        let reply = try await call(.PATCH, "v1/owner/districts/\(districtID)", #"{"name":"Quan Moi","delivery_fee_vnd":25000}"#)
        XCTAssertEqual(reply.status, .ok)
        XCTAssertEqual(reply.json["delivery_fee_vnd"] as? Int, 25_000)
        let named = try await changeCount(field: "name", old: "Quan An Phu", new: "Quan Moi")
        XCTAssertEqual(named, 1)
        let flag = try await changeRows("district")
        XCTAssertEqual(flag, 2, "is_active did not change, so it is not recorded")
        let empty = try await call(.PATCH, "v1/owner/districts/\(districtID)", "{}")
        XCTAssertEqual(problems(empty), ["BODY_EMPTY"])
    }

    func testTheLastActiveDistrictCannotBeSwitchedOffAndOthersCan() async throws {
        let refused = try await call(.PATCH, "v1/owner/districts/\(districtID)", #"{"is_active":false}"#)
        XCTAssertEqual(refused.status, .conflict)
        XCTAssertEqual(refused.errorCode, "LAST_ACTIVE_DISTRICT")
        let second = try await call(.POST, "v1/owner/districts", #"{"name":"B","delivery_fee_vnd":1000}"#)
        let off = try await call(.PATCH, "v1/owner/districts/\(districtID)", #"{"is_active":false}"#)
        XCTAssertEqual(off.status, .ok)
        XCTAssertEqual(off.json["is_active"] as? Bool, false)
        let last = try await call(.PATCH, "v1/owner/districts/\(second.string("district_id"))", #"{"is_active":false}"#)
        XCTAssertEqual(last.errorCode, "LAST_ACTIVE_DISTRICT")
        let back = try await call(.PATCH, "v1/owner/districts/\(districtID)", #"{"is_active":true}"#)
        XCTAssertEqual(back.json["is_active"] as? Bool, true)
        let active = try await count("SELECT count(*)::int AS n FROM district WHERE shop_id = \(bind: shopID) AND is_active")
        XCTAssertEqual(active, 2)
    }

    func testUnknownIdsAreNotFound() async throws {
        for path in ["districts", "slots"] {
            let unknown = try await call(.PATCH, "v1/owner/\(path)/\(UUID())", #"{"is_active":true}"#)
            XCTAssertEqual(unknown.status, .notFound, path)
            XCTAssertEqual(unknown.errorCode, "NOT_FOUND")
            let garbage = try await call(.PATCH, "v1/owner/\(path)/not-an-id", #"{"is_active":true}"#)
            XCTAssertEqual(garbage.status, .notFound, path)
        }
    }

    func testAddingASlotKeepsTheCatalogInClockOrder() async throws {
        let reply = try await call(.POST, "v1/owner/slots", #"{"start":"06:30","end":"08:00"}"#)
        XCTAssertEqual(reply.status, .created)
        XCTAssertEqual(reply.json["start"] as? String, "06:30")
        XCTAssertEqual(reply.json["is_active"] as? Bool, true)
        let catalog = try await send(.GET, "v1/catalog")
        let starts = (catalog.json["slots"] as? [[String: Any]] ?? []).compactMap { $0["start"] as? String }
        XCTAssertEqual(starts, ["06:30", "08:00"])
    }

    func testSlotValidationAndDuplicates() async throws {
        let backwards = try await call(.POST, "v1/owner/slots", #"{"start":"10:00","end":"09:00"}"#)
        XCTAssertEqual(problems(backwards), ["END_OUT_OF_RANGE"])
        let same = try await call(.POST, "v1/owner/slots", #"{"start":"09:00","end":"09:00"}"#)
        XCTAssertEqual(problems(same), ["END_OUT_OF_RANGE"])
        let format = try await call(.POST, "v1/owner/slots", #"{"start":"8:00","end":"24:00"}"#)
        XCTAssertEqual(problems(format), ["START_INVALID", "END_INVALID"])
        let twin = try await call(.POST, "v1/owner/slots", #"{"start":"08:00","end":"10:00"}"#)
        XCTAssertEqual(twin.status, .unprocessableEntity)
        XCTAssertEqual(twin.errorCode, "SLOT_DUPLICATE")
        let fresh = try await call(.POST, "v1/owner/slots", #"{"start":"10:00","end":"12:00"}"#)
        let clash = try await call(.PATCH, "v1/owner/slots/\(fresh.string("slot_id"))", #"{"start":"08:00","end":"10:00"}"#)
        XCTAssertEqual(clash.errorCode, "SLOT_DUPLICATE")
        let early = try await call(.PATCH, "v1/owner/slots/\(fresh.string("slot_id"))", #"{"end":"09:00"}"#)
        XCTAssertEqual(problems(early), ["END_OUT_OF_RANGE"])
        let rows = try await changeRows("slot")
        XCTAssertEqual(rows, 3, "only the one accepted slot was recorded")
    }

    func testTheLastActiveSlotCannotBeSwitchedOff() async throws {
        let refused = try await call(.PATCH, "v1/owner/slots/\(slotID)", #"{"is_active":false}"#)
        XCTAssertEqual(refused.status, .conflict)
        XCTAssertEqual(refused.errorCode, "LAST_ACTIVE_SLOT")
        let second = try await call(.POST, "v1/owner/slots", #"{"start":"14:00","end":"16:00"}"#)
        let moved = try await call(.PATCH, "v1/owner/slots/\(slotID)", #"{"start":"07:00","is_active":false}"#)
        XCTAssertEqual(moved.status, .ok)
        XCTAssertEqual(moved.json["start"] as? String, "07:00")
        let last = try await call(.PATCH, "v1/owner/slots/\(second.string("slot_id"))", #"{"is_active":false}"#)
        XCTAssertEqual(last.errorCode, "LAST_ACTIVE_SLOT")
        let stored = try await call(.GET, "v1/owner/settings")
        XCTAssertEqual(list("slots", in: stored).compactMap { $0["is_active"] as? Bool }, [false, true])
    }

    func testARefusedChangeLeavesEveryFieldAndTheRecordUntouched() async throws {
        let refused = try await call(.PATCH, "v1/owner/districts/\(districtID)", #"{"name":"Renamed","delivery_fee_vnd":5,"is_active":false}"#)
        XCTAssertEqual(refused.errorCode, "LAST_ACTIVE_DISTRICT")
        let slot = try await call(.PATCH, "v1/owner/slots/\(slotID)", #"{"start":"07:00","is_active":false}"#)
        XCTAssertEqual(slot.errorCode, "LAST_ACTIVE_SLOT")
        let district = try await count("SELECT count(*)::int AS n FROM district WHERE id = \(bind: districtID) AND name = 'Quan An Phu' AND delivery_fee_vnd = 20000")
        XCTAssertEqual(district, 1)
        let times = try await count("SELECT count(*)::int AS n FROM delivery_slot WHERE id = \(bind: slotID) AND start_time = '08:00'")
        XCTAssertEqual(times, 1)
        let rows = try await count("SELECT count(*)::int AS n FROM settings_change WHERE shop_id = \(bind: shopID)")
        XCTAssertEqual(rows, 0)
    }

    func testTheChangeRecordCannotBeEditedOrDeleted() async throws {
        _ = try await call(.POST, "v1/owner/slots", #"{"start":"14:00","end":"16:00"}"#)
        for statement: SQLQueryString in [
            "UPDATE settings_change SET new_value = 'x'", "DELETE FROM settings_change"
        ] {
            do { try await run(statement); XCTFail("accepted: \(statement)") } catch {}
        }
    }
}
