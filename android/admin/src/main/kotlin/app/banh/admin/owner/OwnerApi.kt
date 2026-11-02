package app.banh.admin.owner

import app.banh.core.model.Cake
import app.banh.core.model.District
import app.banh.core.model.OrderingImpact
import app.banh.core.model.OrderingSaved
import app.banh.core.model.OwnerSettings
import app.banh.core.model.ShopInfo
import app.banh.core.model.DeliverySlot
import app.banh.core.model.StaffAccount

/** A new cake: the picture is already a JPEG within the limits of ADR-0025. */
class CakeUpload(val name: String, val description: String, val priceVnd: Long, val jpeg: ByteArray)

/** Changes of a cake; a null field is not sent (PATCH keeps the rest, api/07 10.17). */
data class CakeChanges(val name: String? = null, val description: String? = null, val priceVnd: Long? = null, val isActive: Boolean? = null)

data class DistrictChanges(val name: String? = null, val feeVnd: Long? = null, val isActive: Boolean? = null)

data class SlotChanges(val start: String? = null, val end: String? = null, val isActive: Boolean? = null)

/** The owner routes (api/07). Every error surfaces as `ApiException`; screens turn it into an [OwnerFailure]. */
interface OwnerApi {
    suspend fun settings(): OwnerSettings

    suspend fun saveShop(shop: ShopInfo): ShopInfo

    suspend fun impact(dailyLimit: Int): OrderingImpact

    suspend fun saveOrdering(dailyLimit: Int, leadDays: Int, minQty: Int): OrderingSaved

    /** [onProgress] gets 0 to 100 while the body goes out; cancelling the calling coroutine stops the upload. */
    suspend fun addCake(upload: CakeUpload, onProgress: (Int) -> Unit): Cake

    suspend fun changeCake(id: String, changes: CakeChanges): Cake

    suspend fun removeCake(id: String)

    suspend fun addDistrict(name: String, feeVnd: Long): District

    suspend fun changeDistrict(id: String, changes: DistrictChanges): District

    suspend fun addSlot(start: String, end: String): DeliverySlot

    suspend fun changeSlot(id: String, changes: SlotChanges): DeliverySlot

    suspend fun staff(): List<StaffAccount>

    suspend fun addStaff(name: String, email: String): StaffAccount

    suspend fun setStaffActive(id: String, active: Boolean): StaffAccount
}
