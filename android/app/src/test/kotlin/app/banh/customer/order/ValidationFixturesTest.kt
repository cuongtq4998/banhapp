package app.banh.customer.order

import app.banh.customer.data.network.ApiJson
import app.banh.customer.testing.ContractFixtures
import java.text.Normalizer
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** ADR-0009 v1.2 through the canonical (version 2) `validation.json`, which the backend and iOS suites read too. */
class ValidationFixturesTest {
    private val root: JsonObject = ApiJson.parseToJsonElement(ContractFixtures.read("validation.json")).jsonObject

    @Test
    fun everyPhoneCaseIsValidOrNotAsTheFixtureSays() {
        val cases = root.getValue("phone").jsonArray
        assertTrue(cases.isNotEmpty())
        cases.forEach { element ->
            val case = element.jsonObject
            val input = case.getValue("input").jsonPrimitive.content
            val valid = case.getValue("valid").jsonPrimitive.boolean
            assertEquals("valid: '$input'", valid, PhoneNumber.isValid(input))
            if (valid) {
                assertEquals("normalized: '$input'", case.getValue("normalized").jsonPrimitive.content, PhoneNumber.normalize(input))
                assertEquals("e164: '$input'", case.getValue("e164").jsonPrimitive.content, PhoneNumber.toE164(input))
            } else {
                assertNull("no e164 for '$input'", PhoneNumber.toE164(input))
            }
        }
    }

    @Test
    fun phonePatternOfTheFixtureIsTheOneOfTheApp() {
        val pattern = Regex(root.getValue("phone_pattern").jsonPrimitive.content)
        root.getValue("phone").jsonArray.map { it.jsonObject }.forEach { case ->
            val input = case.getValue("input").jsonPrimitive.content
            assertEquals("pattern: '$input'", case.getValue("valid").jsonPrimitive.boolean, pattern.matches(PhoneNumber.normalize(input)))
        }
    }

    @Test
    fun limitsOfTheFixtureAreTheLimitsOfTheApp() {
        val limits = root.getValue("text_limits").jsonObject

        assertEquals(limits.getValue("name").jsonPrimitive.int, FieldRules.NAME_MAX)
        assertEquals(limits.getValue("address").jsonPrimitive.int, FieldRules.ADDRESS_MAX)
        assertEquals(limits.getValue("note").jsonPrimitive.int, FieldRules.NOTE_MAX)
        assertEquals(root.getValue("quantity_max_per_cake").jsonPrimitive.int, OrderFlowState.DEFAULT_MAX_QTY_PER_CAKE)
    }

    @Test
    fun everyTextCaseIsValidOrNotAsTheFixtureSays() {
        val cases = root.getValue("text").jsonArray
        assertTrue(cases.isNotEmpty())
        cases.forEach { element ->
            val case = element.jsonObject
            val field = TextInput.valueOf(case.getValue("field").jsonPrimitive.content.uppercase())
            val text = case["value"]?.jsonPrimitive?.content
                ?: case.getValue("repeat").jsonPrimitive.content.repeat(case.getValue("count").jsonPrimitive.int)
            val expected = case.getValue("valid").jsonPrimitive.boolean
            assertEquals("$field case: ${case["reason"] ?: text.take(20)}", expected, FieldRules.isValid(field, text))
        }
    }

    @Test
    fun composedAndDecomposedFormsCountTheSame() {
        val case = root.getValue("decomposed").jsonObject
        val composed = case.getValue("composed").jsonPrimitive.content
        val decomposed = case.getValue("decomposed").jsonPrimitive.content
        val length = case.getValue("length_after_nfc").jsonPrimitive.int

        assertEquals(length, FieldRules.lengthOf(composed))
        assertEquals(length, FieldRules.lengthOf(decomposed))
        assertEquals(Normalizer.normalize(decomposed, Normalizer.Form.NFC), FieldRules.normalizeForSubmit(decomposed))
    }

    @Test
    fun everyQuantityCaseIsValidOrNotAsTheFixtureSays() {
        val max = root.getValue("quantity_max_per_cake").jsonPrimitive.int
        val cases = root.getValue("quantity").jsonArray
        assertTrue(cases.isNotEmpty())
        cases.forEach { element ->
            val case = element.jsonObject
            val perCake = case.getValue("per_cake").jsonPrimitive.int
            assertEquals("quantity $perCake", case.getValue("valid").jsonPrimitive.boolean, perCake in 1..max)
        }
    }
}
