package app.banh.admin.live

import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue

/** Requests the scenario makes next to the screens: tidy-ups of earlier runs and the per-phone count check (docs/engineering/dev-guide.md, "Live operating flow"). */
object LiveHelpers {
    // Open orders left by earlier runs (this shop is a test shop) would sit above this run's orders; cancel them with a plain reason.
    fun cancelOrdersOfEarlierRuns(code1: String, code2: String): String {
        val token = LiveSupport.appToken()
        val items = LiveSupport.call("GET", "/v1/admin/orders?status=todo", token).json().getJSONArray("items")
        val log = StringBuilder("cancelled orders of earlier runs:\n")
        for (i in 0 until items.length()) {
            val item = items.getJSONObject(i)
            val code = item.getString("order_code")
            if (code == code1 || code == code2) continue
            val answer = LiveSupport.call("POST", "/v1/admin/orders/$code/status", token, "{\"expected_status\":\"${item.getString("status")}\",\"to_status\":\"Cancelled\",\"cancel_reason\":\"customer_asked\"}")
            log.appendLine("$code -> HTTP ${answer.status}")
        }
        return log.toString()
    }

    // Order 1 and the cancelled spam order 2 are 2 of the 5 orders the phone may place; if the spam one still counts, the 3rd helper order is the last accepted.
    fun perPhoneCount(): String {
        val catalog = LiveSupport.call("GET", "/v1/catalog").json()
        val product = catalog.getJSONArray("products").getJSONObject(0)
        val availability = LiveSupport.call("GET", "/v1/availability?cakes=2").json().getJSONArray("dates")
        val later = (0 until availability.length()).map { availability.getJSONObject(it) }.filter { it.getBoolean("available") }[4].getString("date")
        val fee = catalog.getJSONArray("districts").getJSONObject(0)
        val body = """{"items":[{"product_id":"${product.getString("product_id")}","quantity":2}],"delivery_date":"$later",
            "slot_id":"${catalog.getJSONArray("slots").getJSONObject(0).getString("slot_id")}","customer":{"name":"Helper Limit Test","phone":"${LiveSupport.state("phone")}",
            "address":"1 Helper Street","district_id":"${fee.getString("district_id")}"},"note":null,"expected_total_vnd":${2 * product.getInt("price_vnd") + fee.getInt("delivery_fee_vnd")}}"""
        val log = StringBuilder()
        val created = mutableListOf<String>()
        repeat(4) { n ->
            val answer = LiveSupport.call("POST", "/v1/orders", json = body, headers = mapOf("Idempotency-Key" to UUID.randomUUID().toString()))
            log.appendLine("helper order ${n + 3} of this phone: HTTP ${answer.status} ${answer.body}")
            if (answer.status == 201) created += answer.json().getString("order_code")
        }
        val token = LiveSupport.appToken()
        created.forEach { code ->
            val cancel = LiveSupport.call("POST", "/v1/admin/orders/$code/status", token, """{"expected_status":"New","to_status":"Cancelled","cancel_reason":"customer_asked"}""")
            log.appendLine("tidy: cancel $code -> HTTP ${cancel.status}")
        }
        assertEquals("three helper orders accepted, the 4th refused: $log", 3, created.size)
        assertTrue(log.toString(), log.contains("HTTP 429") && log.contains("RATE_LIMITED"))
        return log.toString()
    }

    // Test cakes of earlier runs would crowd the customer catalog pictures; remove them first (BR-12 removal, the shop's own test data).
    fun removeCakesOfEarlierRuns(keep: String): String {
        val token = LiveSupport.appToken()
        val cakes = LiveSupport.call("GET", "/v1/owner/settings", token).json().getJSONArray("cakes")
        val log = StringBuilder("removed test cakes of earlier runs:\n")
        for (i in 0 until cakes.length()) {
            val cake = cakes.getJSONObject(i)
            val name = cake.getString("name")
            if (name == keep || !name.matches(Regex("B[aá]nh E2E.*"))) continue
            log.appendLine("$name -> HTTP ${LiveSupport.call("DELETE", "/v1/owner/cakes/${cake.getString("cake_id")}", token).status}")
        }
        return log.toString()
    }
}
