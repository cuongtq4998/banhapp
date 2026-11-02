#if DEBUG
import Foundation

/// The fake shop behind the owner routes of the stub: mirrors `contracts/fixtures/admin/owner-*.json`
/// (fake names, fake addresses). `full` is 12 cakes and 30 active staff, to reach the limits.
nonisolated enum StubOwnerData {
    private static func cake(_ n: Int, _ name: String, active: Bool = true) -> Cake {
        Cake(
            cakeId: String(format: "5b0c2f6a-0000-4a00-8000-0000000000c%02d", n), name: name, description: "Banh mau \(n)",
            priceVnd: 100_000 + n * 10_000, isActive: active, imageUrl: "/assets/cakes/\(n)?v=0a1b2c3d"
        )
    }

    static func settings(full: Bool) -> OwnerSettings {
        var cakes = [cake(1, "Banh Mau"), cake(2, "Banh Chuoi"), cake(3, "Banh Dau", active: false)]
        if full { cakes += (4...12).map { cake($0, "Banh So \($0)") } }
        return OwnerSettings(
            shop: ShopInfo(name: "Tiem Banh Mau", greeting: "Xin chao", phoneContact: "+84900000000", zaloContact: "zalo.me/tiembanhmau"),
            ordering: OrderingRules(dailyLimit: 60, leadDays: 2, minQty: 2, maxDaysAhead: 30),
            cakes: cakes,
            districts: [
                OwnerDistrict(districtId: "5b0c2f6a-0000-4a00-8000-0000000000d1", name: "Quan An Phu", deliveryFeeVnd: 20_000, isActive: true),
                OwnerDistrict(districtId: "5b0c2f6a-0000-4a00-8000-0000000000d2", name: "Quan Thao Dien", deliveryFeeVnd: 30_000, isActive: false),
            ],
            slots: [
                OwnerSlot(slotId: "5b0c2f6a-0000-4a00-8000-0000000000e1", start: "08:00", end: "10:00", isActive: true),
                OwnerSlot(slotId: "5b0c2f6a-0000-4a00-8000-0000000000e2", start: "14:00", end: "16:00", isActive: false),
            ],
            cakeCountMax: 12, staffCountMax: 30
        )
    }

    static func staff(full: Bool) -> [StaffAccount] {
        var accounts = [
            StaffAccount(accountId: "5b0c2f6a-0000-4a00-8000-0000000000a1", name: "Chu Tiem", email: ownerEmail, role: .owner, isActive: true),
            StaffAccount(accountId: "5b0c2f6a-0000-4a00-8000-0000000000a2", name: "Nhan Vien A", email: "nhanvien.a@example.com", role: .staff, isActive: true),
            StaffAccount(accountId: "5b0c2f6a-0000-4a00-8000-0000000000a3", name: "Nhan Vien B", email: "nhanvien.b@example.com", role: .staff, isActive: false),
        ]
        if full {
            accounts += (4...32).map {
                StaffAccount(accountId: String(format: "5b0c2f6a-0000-4a00-8000-0000000000b%02d", $0), name: "Nhan Vien \($0)", email: "nv\($0)@example.com", role: .staff, isActive: true)
            }
        }
        return accounts
    }

    static let ownerEmail = "chu.tiem@example.com"

    /// Dates already holding more cakes than a lower limit would allow (for the impact preview).
    static let accepted: [(date: String, cakes: Int)] = [("2026-11-05", 98), ("2026-11-06", 70), ("2026-11-09", 12)]
}
#endif
