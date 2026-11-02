#if DEBUG
import Foundation

/// Districts, slots, cakes and staff of the stub owner backend.
extension StubOwnerBackend {
    private func notFound() -> (Int, Data) { StubReply.error(404, "NOT_FOUND", "ERR_NOT_FOUND") }

    // MARK: Districts

    func addDistrict(_ json: [String: Any]) -> (Int, Data) {
        guard let name = text(json, "name"), !name.isEmpty, let fee = json["delivery_fee_vnd"] as? Int, (1...10_000_000).contains(fee) else {
            return validation([("name", "NAME_REQUIRED")])
        }
        if settings.districts.contains(where: { $0.name.lowercased() == name.lowercased() }) { return validation([("name", "NAME_TAKEN")]) }
        let district = OwnerDistrict(districtId: newID("0000000d"), name: name, deliveryFeeVnd: fee, isActive: true)
        settings.districts.append(district)
        return StubReply.codable(201, district)
    }

    func patchDistrict(_ id: String, _ json: [String: Any]) -> (Int, Data) {
        guard let index = settings.districts.firstIndex(where: { $0.districtId == id }) else { return notFound() }
        if let name = text(json, "name") {
            if settings.districts.contains(where: { $0.districtId != id && $0.name.lowercased() == name.lowercased() }) {
                return validation([("name", "NAME_TAKEN")])
            }
            settings.districts[index].name = name
        }
        if let fee = json["delivery_fee_vnd"] as? Int { settings.districts[index].deliveryFeeVnd = fee }
        if let active = json["is_active"] as? Bool {
            if !active, settings.districts.filter(\.isActive).count == 1, settings.districts[index].isActive {
                return StubReply.error(409, "LAST_ACTIVE_DISTRICT", "ERR_LAST_ACTIVE_DISTRICT")
            }
            settings.districts[index].isActive = active
        }
        return StubReply.codable(200, settings.districts[index])
    }

    // MARK: Slots

    func addSlot(_ json: [String: Any]) -> (Int, Data) {
        guard let start = json["start"] as? String, let end = json["end"] as? String else { return validation([("start", "START_INVALID")]) }
        if end <= start { return validation([("end", "END_OUT_OF_RANGE")]) }
        if settings.slots.contains(where: { $0.start == start && $0.end == end }) { return StubReply.error(422, "SLOT_DUPLICATE", "ERR_SLOT_DUPLICATE") }
        let slot = OwnerSlot(slotId: newID("0000000e"), start: start, end: end, isActive: true)
        settings.slots.append(slot)
        settings.slots.sort { ($0.start, $0.end) < ($1.start, $1.end) }
        return StubReply.codable(201, slot)
    }

    func patchSlot(_ id: String, _ json: [String: Any]) -> (Int, Data) {
        guard let index = settings.slots.firstIndex(where: { $0.slotId == id }) else { return notFound() }
        var slot = settings.slots[index]
        slot.start = (json["start"] as? String) ?? slot.start
        slot.end = (json["end"] as? String) ?? slot.end
        if slot.end <= slot.start { return validation([("end", "END_OUT_OF_RANGE")]) }
        if settings.slots.contains(where: { $0.slotId != id && $0.start == slot.start && $0.end == slot.end }) {
            return StubReply.error(422, "SLOT_DUPLICATE", "ERR_SLOT_DUPLICATE")
        }
        if let active = json["is_active"] as? Bool {
            if !active, slot.isActive, settings.slots.filter(\.isActive).count == 1 {
                return StubReply.error(409, "LAST_ACTIVE_SLOT", "ERR_LAST_ACTIVE_SLOT")
            }
            slot.isActive = active
        }
        settings.slots[index] = slot
        settings.slots.sort { ($0.start, $0.end) < ($1.start, $1.end) }
        return StubReply.codable(200, slot)
    }

    // MARK: Cakes

    func addCake(_ request: URLRequest) -> (Int, Data) {
        let parts = StubMultipart.parse(request)
        if let problem = StubMultipart.imageProblem(parts.files), problem.status == 413 {
            return StubReply.error(413, problem.code, "ERR_IMAGE_TOO_LARGE")
        }
        var bad: [(String, String)] = []
        let name = (parts.fields["name"] ?? "").trimmingCharacters(in: .whitespaces)
        if name.isEmpty { bad.append(("name", "NAME_REQUIRED")) }
        if (parts.fields["description"] ?? "").isEmpty { bad.append(("description", "DESCRIPTION_REQUIRED")) }
        let price = Int(parts.fields["price_vnd"] ?? "")
        if price == nil || !(1...100_000_000).contains(price!) { bad.append(("price_vnd", "PRICE_VND_OUT_OF_RANGE")) }
        if let problem = StubMultipart.imageProblem(parts.files) { bad.append((problem.field, problem.code)) }
        if bad.isEmpty, settings.cakes.contains(where: { $0.name.lowercased() == name.lowercased() }) { bad.append(("name", "NAME_TAKEN")) }
        guard bad.isEmpty else { return validation(bad) }
        if settings.cakes.count >= settings.cakeCountMax { return StubReply.error(409, "CAKE_LIMIT_REACHED", "ERR_CAKE_LIMIT") }
        let cake = Cake(
            cakeId: newID("000000c0"), name: name, description: parts.fields["description"] ?? "", priceVnd: price ?? 0,
            isActive: true, imageUrl: "/assets/cakes/new?v=0a1b2c3d"
        )
        settings.cakes.append(cake)
        return StubReply.codable(201, cake)
    }

    func patchCake(_ id: String, _ json: [String: Any]) -> (Int, Data) {
        guard let index = settings.cakes.firstIndex(where: { $0.cakeId == id }) else { return notFound() }
        if let name = text(json, "name") {
            if settings.cakes.contains(where: { $0.cakeId != id && $0.name.lowercased() == name.lowercased() }) {
                return validation([("name", "NAME_TAKEN")])
            }
            settings.cakes[index].name = name
        }
        if let description = text(json, "description") { settings.cakes[index].description = description }
        if let price = json["price_vnd"] as? Int { settings.cakes[index].priceVnd = price }
        if let active = json["is_active"] as? Bool {
            if !active, settings.cakes[index].isActive, settings.activeCakes == 1 { return StubReply.error(409, "LAST_ACTIVE_CAKE", "ERR_LAST_ACTIVE_CAKE") }
            settings.cakes[index].isActive = active
        }
        return StubReply.codable(200, settings.cakes[index])
    }

    func removeCake(_ id: String) -> (Int, Data) {
        guard let index = settings.cakes.firstIndex(where: { $0.cakeId == id }) else { return notFound() }
        if settings.cakes[index].isActive, settings.activeCakes == 1 { return StubReply.error(409, "LAST_ACTIVE_CAKE", "ERR_LAST_ACTIVE_CAKE") }
        settings.cakes.remove(at: index)
        return (204, Data())
    }
}
#endif
