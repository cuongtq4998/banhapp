package app.banh.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Owner contract types (api/07 sections 10.13 to 10.18). Unknown response fields are ignored by the decoder.

@Serializable
data class ShopInfo(
    val name: String,
    val greeting: String,
    @SerialName("phone_contact") val phoneContact: String,
    @SerialName("zalo_contact") val zaloContact: String,
)

@Serializable
data class OrderingRules(
    @SerialName("daily_limit") val dailyLimit: Int,
    @SerialName("lead_days") val leadDays: Int,
    @SerialName("min_qty") val minQty: Int,
    @SerialName("max_days_ahead") val maxDaysAhead: Int = 30,
)

/** A date that already holds more cakes than the limit being set. */
@Serializable
data class OverLimitDay(val date: String, @SerialName("cakes_accepted") val cakesAccepted: Int)

/** `GET .../ordering/impact` (advisory, writes nothing). */
@Serializable
data class OrderingImpact(
    @SerialName("daily_limit") val dailyLimit: Int,
    @SerialName("over_limit") val overLimit: List<OverLimitDay> = emptyList(),
    val count: Int = 0,
)

/** `PUT .../ordering`: the saved section plus the list that is true at save time. */
@Serializable
data class OrderingSaved(
    @SerialName("daily_limit") val dailyLimit: Int,
    @SerialName("lead_days") val leadDays: Int,
    @SerialName("min_qty") val minQty: Int,
    @SerialName("over_limit") val overLimit: List<OverLimitDay> = emptyList(),
    val count: Int = 0,
)

@Serializable
data class Cake(
    @SerialName("cake_id") val cakeId: String,
    val name: String,
    val description: String,
    @SerialName("price_vnd") val priceVnd: Long,
    @SerialName("is_active") val isActive: Boolean,
    @SerialName("image_url") val imageUrl: String? = null,
)

@Serializable
data class District(
    @SerialName("district_id") val districtId: String,
    val name: String,
    @SerialName("delivery_fee_vnd") val deliveryFeeVnd: Long,
    @SerialName("is_active") val isActive: Boolean,
)

@Serializable
data class DeliverySlot(
    @SerialName("slot_id") val slotId: String,
    val start: String,
    val end: String,
    @SerialName("is_active") val isActive: Boolean,
)

@Serializable
data class OwnerSettings(
    val shop: ShopInfo,
    val ordering: OrderingRules,
    val cakes: List<Cake> = emptyList(),
    val districts: List<District> = emptyList(),
    val slots: List<DeliverySlot> = emptyList(),
    @SerialName("cake_count_max") val cakeCountMax: Int = 12,
    @SerialName("staff_count_max") val staffCountMax: Int = 30,
)

@Serializable
data class StaffAccount(
    @SerialName("account_id") val accountId: String,
    val name: String,
    val email: String,
    val role: Role,
    @SerialName("is_active") val isActive: Boolean,
)

@Serializable
data class StaffList(val accounts: List<StaffAccount>)
