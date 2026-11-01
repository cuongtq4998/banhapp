import BanhContracts
import BanhCore
import Foundation
import Observation

/// S-A10 Delivery: districts with fees and time slots on one screen (FR-23). A switch saves at once.
@Observable
final class DeliveryViewModel {
    private(set) var load: Load<Void> = .loading
    private(set) var districts: [OwnerDistrict] = []
    private(set) var slots: [OwnerSlot] = []
    /// Ids whose switch change is on its way: dimmed and disabled.
    private(set) var pending: Set<String> = []
    var districtEditor: DistrictEditorModel?
    var slotEditor: SlotEditorModel?
    private let api: any OwnerAPI
    private let flash: (String) -> Void

    init(api: any OwnerAPI, flash: @escaping (String) -> Void) {
        self.api = api
        self.flash = flash
    }

    var isBusy: Bool { !pending.isEmpty }

    func reload() async {
        do {
            let settings = try await api.settings()
            districts = settings.districts
            slots = settings.slots
            load = .ready(())
        } catch {
            if !(error is SessionEnded), load.value == nil { load = .failed(error.loadFailure) }
        }
    }

    func retry() async {
        load = .loading
        await reload()
    }

    // MARK: Switches

    func setDistrict(_ district: OwnerDistrict, active: Bool) async {
        await change(district.districtId, lastActiveText: AStrings.errLastDistrict, code: "LAST_ACTIVE_DISTRICT") {
            _ = try await self.api.updateDistrict(id: district.districtId, changes: ["is_active": .bool(active)])
        }
    }

    func setSlot(_ slot: OwnerSlot, active: Bool) async {
        await change(slot.slotId, lastActiveText: AStrings.errLastSlot, code: "LAST_ACTIVE_SLOT") {
            _ = try await self.api.updateSlot(id: slot.slotId, changes: ["is_active": .bool(active)])
        }
    }

    /// On refusal the switch stays as it was (the rows come from the server) and a toast names the rule.
    private func change(_ id: String, lastActiveText: LocalizedStringResource, code: String, _ call: () async throws -> Void) async {
        guard !isBusy else { return }
        pending.insert(id)
        defer { pending.remove(id) }
        do {
            try await call()
            await reload()
        } catch {
            guard !(error is SessionEnded) else { return }
            if (error as? APIError)?.code == code {
                flash(String(localized: lastActiveText))
            } else {
                flash(error.saveMessage)
            }
            await reload()
        }
    }

    // MARK: Editors

    func addDistrict() { districtEditor = DistrictEditorModel(existing: nil, api: api, onSaved: saved) }
    func edit(_ district: OwnerDistrict) { districtEditor = DistrictEditorModel(existing: district, api: api, onSaved: saved) }
    func addSlot() { slotEditor = SlotEditorModel(existing: nil, api: api, onSaved: saved) }
    func edit(_ slot: OwnerSlot) { slotEditor = SlotEditorModel(existing: slot, api: api, onSaved: saved) }

    private func saved() {
        districtEditor = nil
        slotEditor = nil
        flash(String(localized: AStrings.saved))
        Task { await reload() }
    }
}
