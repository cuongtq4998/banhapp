package app.banh.admin.stub

import app.banh.core.model.Cake
import app.banh.core.model.DeliverySlot
import app.banh.core.model.District
import app.banh.core.model.OrderingImpact
import app.banh.core.model.OrderingRules
import app.banh.core.model.OrderingSaved
import app.banh.core.model.OverLimitDay
import app.banh.core.model.OwnerSettings
import app.banh.core.model.Role
import app.banh.core.model.ShopInfo
import app.banh.core.model.StaffAccount
import app.banh.core.model.StaffList
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull

private val json = Json { ignoreUnknownKeys = true }
internal const val OWNER_PREFIX = "v1/owner/"

/**
 * The owner routes of the stub (api/07), stateful like [StubOrders]: it starts from the fixtures `owner-settings` and `owner-staff-list`
 * and answers with the refusals of the error fixtures. Triggers: a cake or staff name containing "full" meets the limit, "slow" delays an
 * upload by 2.5 s (to cancel it), the cake id "gone" does not exist, an e-mail already in the list or "taken" is refused.
 */
internal class StubOwner(private val fixtures: StubBackend.Fixtures) {
    private var settings = json.decodeFromJsonElement(OwnerSettings.serializer(), body("owner-settings")).let {
        // One hidden cake next to the fixture's active one shows both groups of S-A7.
        it.copy(cakes = it.cakes + Cake("5b0c2f6a-0000-4a00-8000-0000000000c3", "Banh Kem", "Banh kem", 220000, false, it.cakes.first().imageUrl))
    }
    private var staff = json.decodeFromJsonElement(StaffList.serializer(), body("owner-staff-list")).accounts
    private var counter = 0

    fun handle(method: String, path: String, request: StubRequest): StubResponse? {
        val route = path.removePrefix(OWNER_PREFIX)
        val parts = route.split("/")
        val sent = request.body?.takeIf { it.startsWith("{") }?.let { json.parseToJsonElement(it).jsonObject }
        return when {
            method == "GET" && route == "settings" -> ok(OwnerSettings.serializer(), settings)
            method == "PUT" && route == "settings/shop" -> shop(sent!!)
            method == "GET" && route == "settings/ordering/impact" -> impact(request.query["daily_limit"]?.toIntOrNull() ?: 0)
            method == "PUT" && route == "settings/ordering" -> ordering(sent!!)
            parts[0] == "cakes" -> cakes(method, parts.getOrNull(1), sent, request)
            parts[0] == "districts" -> districts(method, parts.getOrNull(1), sent!!)
            parts[0] == "slots" -> slots(method, parts.getOrNull(1), sent!!)
            parts[0] == "staff" -> staffRoute(method, parts.getOrNull(1), request.query, sent)
            else -> null
        }
    }

    private fun shop(sent: JsonObject): StubResponse {
        if (sent.str("name").contains("invalid", ignoreCase = true)) return error("error-settings-validation", 422)
        settings = settings.copy(shop = ShopInfo(sent.str("name"), sent.str("greeting"), sent.str("phone_contact"), sent.str("zalo_contact")))
        return ok(ShopInfo.serializer(), settings.shop)
    }

    // Lowering the limit overfills one date (the fixture's 98 cakes on 2026-11-05); raising it overfills none.
    private fun overLimit(limit: Int) = if (limit < OVER_AT) listOf(OverLimitDay("2026-11-05", 98)) else emptyList()

    private fun impact(limit: Int): StubResponse = overLimit(limit).let { ok(OrderingImpact.serializer(), OrderingImpact(limit, it, it.size)) }

    private fun ordering(sent: JsonObject): StubResponse {
        val rules = OrderingRules(sent.num("daily_limit").toInt(), sent.num("lead_days").toInt(), sent.num("min_qty").toInt())
        settings = settings.copy(ordering = rules)
        val found = overLimit(rules.dailyLimit)
        return ok(OrderingSaved.serializer(), OrderingSaved(rules.dailyLimit, rules.leadDays, rules.minQty, found, found.size))
    }

    private fun cakes(method: String, id: String?, sent: JsonObject?, request: StubRequest): StubResponse {
        if (method == "POST") return addCake(request)
        val cake = settings.cakes.firstOrNull { it.cakeId == id } ?: return error("error-order-not-found", 404)
        val active = settings.cakes.count { it.isActive }
        val hides = (method == "DELETE" || sent?.get("is_active")?.jsonPrimitive?.booleanOrNull == false) && cake.isActive && active == 1
        if (hides) return error("error-last-active-cake", 409)
        if (method == "DELETE") {
            settings = settings.copy(cakes = settings.cakes - cake)
            return StubResponse(204)
        }
        val changed = cake.copy(
            name = sent.strOr("name", cake.name),
            description = sent.strOr("description", cake.description),
            priceVnd = sent?.get("price_vnd")?.jsonPrimitive?.longOrNull ?: cake.priceVnd,
            isActive = sent?.get("is_active")?.jsonPrimitive?.booleanOrNull ?: cake.isActive,
        )
        settings = settings.copy(cakes = settings.cakes.map { if (it.cakeId == cake.cakeId) changed else it })
        return ok(Cake.serializer(), changed)
    }

    private fun addCake(request: StubRequest): StubResponse {
        val name = multipart(request.body, "name")
        StubUploads.last = request.bytes?.let(::imagePart)
        if (name.contains("full", ignoreCase = true) || settings.cakes.size >= settings.cakeCountMax) return error("error-cake-limit-reached", 409)
        if (settings.cakes.any { it.name.equals(name, ignoreCase = true) }) return error("error-cake-name-taken", 422)
        val cake = Cake("5b0c2f6a-0000-4a00-8000-0000000000c${++counter + 3}", name, multipart(request.body, "description"), multipart(request.body, "price_vnd").toLong(), true, "/assets/cakes/new?v=0a1b2c3d")
        settings = settings.copy(cakes = settings.cakes + cake)
        return ok(Cake.serializer(), cake, 201)
    }

    private fun districts(method: String, id: String?, sent: JsonObject): StubResponse {
        val name = sent["name"]?.jsonPrimitive?.contentOrNull
        if (name != null && settings.districts.any { it.name.equals(name, ignoreCase = true) && it.districtId != id }) return error("error-cake-name-taken", 422)
        if (method == "POST") {
            val created = District("5b0c2f6a-0000-4a00-8000-0000000000d${++counter + 1}", name!!, sent.num("delivery_fee_vnd"), true)
            settings = settings.copy(districts = settings.districts + created)
            return ok(District.serializer(), created, 201)
        }
        val current = settings.districts.firstOrNull { it.districtId == id } ?: return error("error-order-not-found", 404)
        val off = sent["is_active"]?.jsonPrimitive?.booleanOrNull == false
        if (off && current.isActive && settings.districts.count { it.isActive } == 1) return error("error-last-active-district", 409)
        val changed = current.copy(name = name ?: current.name, deliveryFeeVnd = sent["delivery_fee_vnd"]?.jsonPrimitive?.longOrNull ?: current.deliveryFeeVnd, isActive = sent["is_active"]?.jsonPrimitive?.booleanOrNull ?: current.isActive)
        settings = settings.copy(districts = settings.districts.map { if (it.districtId == id) changed else it })
        return ok(District.serializer(), changed)
    }

    private fun slots(method: String, id: String?, sent: JsonObject): StubResponse {
        val start = sent["start"]?.jsonPrimitive?.contentOrNull
        val end = sent["end"]?.jsonPrimitive?.contentOrNull
        if (method == "POST") {
            if (settings.slots.any { it.start == start && it.end == end }) return error("error-slot-duplicate", 422)
            val created = DeliverySlot("5b0c2f6a-0000-4a00-8000-0000000000e${++counter + 1}", start!!, end!!, true)
            settings = settings.copy(slots = (settings.slots + created).sortedBy { it.start })
            return ok(DeliverySlot.serializer(), created, 201)
        }
        val current = settings.slots.firstOrNull { it.slotId == id } ?: return error("error-order-not-found", 404)
        val off = sent["is_active"]?.jsonPrimitive?.booleanOrNull == false
        if (off && current.isActive && settings.slots.count { it.isActive } == 1) return error("error-last-active-slot", 409)
        val changed = current.copy(start = start ?: current.start, end = end ?: current.end, isActive = sent["is_active"]?.jsonPrimitive?.booleanOrNull ?: current.isActive)
        settings = settings.copy(slots = settings.slots.map { if (it.slotId == id) changed else it }.sortedBy { it.start })
        return ok(DeliverySlot.serializer(), changed)
    }

    private fun staffRoute(method: String, id: String?, query: Map<String, String>, sent: JsonObject?): StubResponse {
        if (method == "GET") return ok(StaffList.serializer(), StaffList(staff))
        if (method == "POST") {
            val email = sent!!.str("email").lowercase()
            if (staff.any { it.email == email } || email.contains("taken")) return error("error-email-taken", 409)
            if (email.contains("full") || sent.str("name").contains("full", ignoreCase = true)) return error("error-staff-limit-reached", 409)
            val created = StaffAccount("5b0c2f6a-0000-4a00-8000-0000000000a${++counter + 2}", sent.str("name"), email, Role.STAFF, true)
            staff = staff + created
            return ok(StaffAccount.serializer(), created, 201)
        }
        val current = staff.firstOrNull { it.accountId == id } ?: return error("error-order-not-found", 404)
        if (current.role == Role.OWNER) return error("error-owner-protected", 409)
        val active = sent!!["is_active"]!!.jsonPrimitive.boolean
        // A staff account named "... Full" cannot be switched on again: the 30 places are taken (AC-9).
        if (active && !current.isActive && current.name.contains("full", ignoreCase = true)) return error("error-staff-limit-reached", 409)
        val changed = current.copy(isActive = active)
        staff = staff.map { if (it.accountId == id) changed else it }
        return ok(StaffAccount.serializer(), changed)
    }

    private fun body(name: String) = json.parseToJsonElement(fixtures.read(name)).jsonObject["body"]!!

    private fun <T> ok(serializer: KSerializer<T>, value: T, status: Int = 200) = StubResponse(status, json.encodeToString(serializer, value))

    private fun error(fixture: String, status: Int) = StubResponse(status, fixtures.read(fixture))

    private fun JsonObject.str(key: String) = (this[key] as? JsonPrimitive)?.contentOrNull.orEmpty()

    private fun JsonObject?.strOr(key: String, fallback: String) = this?.get(key)?.jsonPrimitive?.contentOrNull ?: fallback

    private fun JsonObject.num(key: String) = this[key]!!.jsonPrimitive.longOrNull!!

    // The text of a form-data part: `name="x"` CRLF CRLF value CRLF.
    private fun multipart(body: String?, field: String): String =
        Regex("""name="$field"\r\n(?:Content-[^\r\n]*\r\n)*\r\n(.*?)\r\n--""", RegexOption.DOT_MATCHES_ALL).find(body.orEmpty())?.groupValues?.get(1).orEmpty()

    private companion object {
        const val OVER_AT = 60
    }
}

// The bytes of the `image` part: after the blank line that ends its headers, up to the CRLF before the closing boundary.
private fun imagePart(body: ByteArray): ByteArray? {
    val text = String(body, Charsets.ISO_8859_1)
    val header = text.indexOf("name=\"image\"")
    if (header < 0) return null
    val start = text.indexOf("\r\n\r\n", header) + 4
    val end = text.lastIndexOf("\r\n--")
    return if (start in 4..end) body.copyOfRange(start, end) else null
}

/** What the stub received as the last cake upload (tests check the picture's size, signature and dimensions). */
object StubUploads {
    @Volatile
    var last: ByteArray? = null
}
