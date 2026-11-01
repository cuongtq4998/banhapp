package app.banh.admin.owner

import app.banh.admin.auth.SessionManager
import app.banh.admin.auth.bearer
import app.banh.core.model.Cake
import app.banh.core.model.District
import app.banh.core.model.OrderingImpact
import app.banh.core.model.OrderingSaved
import app.banh.core.model.OwnerSettings
import app.banh.core.model.ShopInfo
import app.banh.core.model.DeliverySlot
import app.banh.core.model.StaffAccount
import app.banh.core.model.StaffList
import app.banh.core.network.ApiClient
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody

private const val OWNER = "v1/owner"

/** Owner endpoints (api/07); every call goes through [SessionManager.authorized]. */
class HttpOwnerApi(private val client: ApiClient, private val session: SessionManager) : OwnerApi {
    override suspend fun settings(): OwnerSettings = send("GET", "settings", null, OwnerSettings.serializer())

    override suspend fun saveShop(shop: ShopInfo): ShopInfo =
        send("PUT", "settings/shop", body("name" to shop.name, "greeting" to shop.greeting, "phone_contact" to shop.phoneContact, "zalo_contact" to shop.zaloContact), ShopInfo.serializer())

    override suspend fun impact(dailyLimit: Int): OrderingImpact =
        session.authorized { client.get("$OWNER/settings/ordering/impact", OrderingImpact.serializer(), listOf("daily_limit" to dailyLimit.toString()), bearer(it)) }

    override suspend fun saveOrdering(dailyLimit: Int, leadDays: Int, minQty: Int): OrderingSaved =
        send("PUT", "settings/ordering", body("daily_limit" to dailyLimit, "lead_days" to leadDays, "min_qty" to minQty), OrderingSaved.serializer())

    override suspend fun addCake(upload: CakeUpload, onProgress: (Int) -> Unit): Cake {
        val multipart = MultipartBody.Builder().setType(MultipartBody.FORM)
            .addFormDataPart("name", upload.name)
            .addFormDataPart("description", upload.description)
            .addFormDataPart("price_vnd", upload.priceVnd.toString())
            .addFormDataPart("image", "cake.jpg", ProgressBody(upload.jpeg.toRequestBody("image/jpeg".toMediaType()), onProgress))
            .build()
        return session.authorized { client.decode(client.execute("POST", "$OWNER/cakes", headers = bearer(it), body = multipart), Cake.serializer()) }
    }

    override suspend fun changeCake(id: String, changes: CakeChanges): Cake =
        send("PATCH", "cakes/$id", body("name" to changes.name, "description" to changes.description, "price_vnd" to changes.priceVnd, "is_active" to changes.isActive), Cake.serializer())

    override suspend fun removeCake(id: String) {
        session.authorized { client.execute("DELETE", "$OWNER/cakes/$id", headers = bearer(it)) }
    }

    override suspend fun addDistrict(name: String, feeVnd: Long): District =
        send("POST", "districts", body("name" to name, "delivery_fee_vnd" to feeVnd), District.serializer())

    override suspend fun changeDistrict(id: String, changes: DistrictChanges): District =
        send("PATCH", "districts/$id", body("name" to changes.name, "delivery_fee_vnd" to changes.feeVnd, "is_active" to changes.isActive), District.serializer())

    override suspend fun addSlot(start: String, end: String): DeliverySlot = send("POST", "slots", body("start" to start, "end" to end), DeliverySlot.serializer())

    override suspend fun changeSlot(id: String, changes: SlotChanges): DeliverySlot =
        send("PATCH", "slots/$id", body("start" to changes.start, "end" to changes.end, "is_active" to changes.isActive), DeliverySlot.serializer())

    override suspend fun staff(): List<StaffAccount> = send("GET", "staff", null, StaffList.serializer()).accounts

    override suspend fun addStaff(name: String, email: String): StaffAccount =
        send("POST", "staff", body("name" to name, "email" to email), StaffAccount.serializer())

    override suspend fun setStaffActive(id: String, active: Boolean): StaffAccount =
        send("PATCH", "staff/$id", body("is_active" to active), StaffAccount.serializer())

    private suspend fun <T> send(method: String, path: String, json: JsonObject?, serializer: KSerializer<T>): T =
        session.authorized { client.decode(client.execute(method, "$OWNER/$path", jsonBody = json?.toString(), headers = bearer(it)), serializer) }
}

/** A JSON object of the given values; null values are left out (a PATCH sends only what changed). */
internal fun body(vararg pairs: Pair<String, Any?>): JsonObject = JsonObject(
    pairs.mapNotNull { (key, value) ->
        when (value) {
            null -> null
            is Boolean -> key to JsonPrimitive(value)
            is Number -> key to JsonPrimitive(value)
            else -> key to JsonPrimitive(value.toString())
        }
    }.toMap(),
)
