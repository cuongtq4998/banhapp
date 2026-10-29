package app.banh.customer.order

import app.banh.customer.data.network.ApiJson
import app.banh.customer.testing.ContractFixtures
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** ADR-0009 through the shared `validation.json`, which the backend and iOS suites read too. */
class ValidationFixturesTest {
    private val root: JsonObject = ApiJson.parseToJsonElement(ContractFixtures.read("validation.json")).jsonObject

    @Test
    fun everyPhoneCaseNormalizesAndValidatesAsTheFixtureSays() {
        val cases = root.getValue("phone_cases").jsonArray
        assertTrue(cases.isNotEmpty())
        cases.forEach { element ->
            val case = element.jsonObject
            val input = case.getValue("input").jsonPrimitive.content
            assertEquals("normalized: '$input'", case.getValue("normalized").jsonPrimitive.content, PhoneNumber.normalize(input))
            assertEquals("valid: '$input'", case.getValue("valid").jsonPrimitive.boolean, PhoneNumber.isValid(input))
            assertEquals("e164: '$input'", case.getValue("e164").jsonPrimitive.contentOrNull, PhoneNumber.toE164(input))
        }
    }

    @Test
    fun limitsOfTheFixtureAreTheLimitsOfTheApp() {
        val limits = root.getValue("text_limits").jsonObject

        assertEquals(limits.getValue("name").jsonPrimitive.int, FieldRules.NAME_MAX)
        assertEquals(limits.getValue("address").jsonPrimitive.int, FieldRules.ADDRESS_MAX)
        assertEquals(limits.getValue("note").jsonPrimitive.int, FieldRules.NOTE_MAX)
        assertEquals(root.getValue("quantity_max_per_cake").jsonPrimitive.intOrNull, OrderFlowState.DEFAULT_MAX_QTY_PER_CAKE)
    }

    @Test
    fun everyTextCaseIsValidOrNotAsTheFixtureSays() {
        val cases = root.getValue("text_cases").jsonArray
        assertTrue(cases.isNotEmpty())
        cases.forEach { element ->
            val case = element.jsonObject
            val field = TextInput.valueOf(case.getValue("field").jsonPrimitive.content.uppercase())
            val repeat = case["repeat"]?.jsonPrimitive?.int ?: 1
            val text = case.getValue("text").jsonPrimitive.content.repeat(repeat)
            val expected = case.getValue("valid").jsonPrimitive.boolean
            assertEquals("$field case: ${case["reason"] ?: text.take(20)}", expected, FieldRules.isValid(field, text))
        }
    }
}
