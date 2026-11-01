package app.banh.admin.testing

import app.banh.admin.owner.CakeChanges
import app.banh.admin.owner.CakeUpload
import app.banh.admin.owner.DistrictChanges
import app.banh.admin.owner.OwnerApi
import app.banh.admin.owner.SlotChanges
import app.banh.core.model.Cake
import app.banh.core.model.DeliverySlot
import app.banh.core.model.District
import app.banh.core.model.OrderingImpact
import app.banh.core.model.OrderingSaved
import app.banh.core.model.OverLimitDay
import app.banh.core.model.OwnerSettings
import app.banh.core.model.Role
import app.banh.core.model.ShopInfo
import app.banh.core.model.StaffAccount
import kotlinx.serialization.json.Json

val ownerSettingsFixture: OwnerSettings = Json { ignoreUnknownKeys = true }.decodeFromString(Fixtures.body("owner-settings"))

val cakeFixture: Cake = ownerSettingsFixture.cakes.first()

/** Records the calls; set [failure] to make every call throw it, or [gate] to hold a call until the test lets it go. */
class FakeOwnerApi : OwnerApi {
    val calls = mutableListOf<String>()
    var failure: Throwable? = null
    var settings = ownerSettingsFixture
    var impactDays = emptyList<OverLimitDay>()
    var savedDays = emptyList<OverLimitDay>()
    var staff = listOf(StaffAccount("a1", "Chu", "chu@example.com", Role.OWNER, true), StaffAccount("a2", "Nhan Vien", "nv@example.com", Role.STAFF, true))
    var lastUpload: CakeUpload? = null
    var gate: kotlinx.coroutines.CompletableDeferred<Unit>? = null

    private suspend fun <T> run(call: String, result: () -> T): T {
        calls += call
        gate?.await()
        failure?.let { throw it }
        return result()
    }

    override suspend fun settings() = run("settings") { settings }

    override suspend fun saveShop(shop: ShopInfo) = run("saveShop ${shop.phoneContact}") { shop }

    override suspend fun impact(dailyLimit: Int) = run("impact $dailyLimit") { OrderingImpact(dailyLimit, impactDays, impactDays.size) }

    override suspend fun saveOrdering(dailyLimit: Int, leadDays: Int, minQty: Int) =
        run("saveOrdering $dailyLimit $leadDays $minQty") { OrderingSaved(dailyLimit, leadDays, minQty, savedDays, savedDays.size) }

    override suspend fun addCake(upload: CakeUpload, onProgress: (Int) -> Unit) = run("addCake ${upload.name}") {
        lastUpload = upload
        onProgress(100)
        cakeFixture.copy(name = upload.name, priceVnd = upload.priceVnd)
    }

    override suspend fun changeCake(id: String, changes: CakeChanges) = run("changeCake $id $changes") { cakeFixture }

    override suspend fun removeCake(id: String) = run("removeCake $id") { Unit }

    override suspend fun addDistrict(name: String, feeVnd: Long) = run("addDistrict $name $feeVnd") { ownerSettingsFixture.districts.first() }

    override suspend fun changeDistrict(id: String, changes: DistrictChanges): District = run("changeDistrict $id $changes") { ownerSettingsFixture.districts.first() }

    override suspend fun addSlot(start: String, end: String) = run("addSlot $start $end") { ownerSettingsFixture.slots.first() }

    override suspend fun changeSlot(id: String, changes: SlotChanges): DeliverySlot = run("changeSlot $id $changes") { ownerSettingsFixture.slots.first() }

    override suspend fun staff() = run("staff") { staff }

    override suspend fun addStaff(name: String, email: String) = run("addStaff $name $email") { staff.last() }

    override suspend fun setStaffActive(id: String, active: Boolean) = run("setStaffActive $id $active") { staff.last() }
}
