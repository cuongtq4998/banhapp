package app.banh.customer.data.catalog

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Body of `GET /v1/catalog` (docs/system/api.md 4.1 and section 3). */
@Serializable
data class Catalog(
    /** Today in shop time; later slices use it instead of the device date (ADR-0007). */
    @SerialName("server_date") val serverDate: String,
    val shop: Shop,
    val settings: Settings,
    /** Every active product, ordered; 1 to 4 is normal. An empty list is the only failed-load case. */
    val products: List<Product>,
    val districts: List<District>,
    val slots: List<Slot>,
)

@Serializable
data class Shop(
    val name: String,
    val greeting: String,
    /** Dial number in E.164. */
    @SerialName("phone_contact") val phoneContact: String,
    /** Zalo number in international form without `+` (ADR-0015). */
    @SerialName("zalo_contact") val zaloContact: String,
)

@Serializable
data class Settings(
    @SerialName("min_qty") val minQty: Int,
    @SerialName("lead_days") val leadDays: Int,
    @SerialName("max_days_ahead") val maxDaysAhead: Int,
    @SerialName("max_qty_per_cake") val maxQtyPerCake: Int,
    @SerialName("note_max_length") val noteMaxLength: Int,
)

@Serializable
data class Product(
    @SerialName("product_id") val id: String,
    val slug: String,
    val name: String,
    val description: String,
    /** Whole dong (BR-5). */
    @SerialName("price_vnd") val priceVnd: Long,
    /** Path on the API host, for example `/assets/products/<slug>.jpg`. */
    @SerialName("image_url") val imageUrl: String,
)

@Serializable
data class District(
    @SerialName("district_id") val id: String,
    val name: String,
    @SerialName("delivery_fee_vnd") val deliveryFeeVnd: Long,
)

@Serializable
data class Slot(
    @SerialName("slot_id") val id: String,
    /** `HH:MM`. */
    val start: String,
    /** `HH:MM`. */
    val end: String,
)
