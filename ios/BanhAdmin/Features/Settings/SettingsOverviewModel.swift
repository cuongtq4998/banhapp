import BanhCore
import Foundation
import Observation

/// Row values of S-A6: cake count, ordering limit, delivery counts, shop name, active staff count.
@Observable
final class SettingsOverviewModel {
    private(set) var settings: Load<OwnerSettings> = .loading
    private(set) var activeStaff: Int?
    private let api: any OwnerAPI

    init(api: any OwnerAPI) { self.api = api }

    /// Silent when values are already shown: the rows keep their old values until the new ones arrive.
    func load() async {
        async let staff = try? await api.staff()
        do {
            settings = .ready(try await api.settings())
        } catch {
            if case .ready = settings {} else { settings = .failed(error.loadFailure) }
        }
        activeStaff = (await staff)?.filter { $0.role == .staff && $0.isActive }.count
    }

    private static let dash = "–"

    var cakesValue: String {
        settings.value.map { "\($0.cakes.count)/\($0.cakeCountMax)" } ?? Self.dash
    }

    var rulesValue: String { settings.value.map { AStrings.rowRulesValue(limit: $0.ordering.dailyLimit) } ?? Self.dash }

    var deliveryValue: String {
        guard let value = settings.value else { return Self.dash }
        return AStrings.rowDeliveryValue(
            districts: value.districts.filter(\.isActive).count, slots: value.slots.filter(\.isActive).count
        )
    }

    var shopValue: String { settings.value?.shop.name ?? Self.dash }

    var staffValue: String {
        guard let activeStaff, let max = settings.value?.staffCountMax else {
            return activeStaff.map { "\($0)/30" } ?? Self.dash
        }
        return "\(activeStaff)/\(max)"
    }
}
