package app.banh.customer.order

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FieldRulesTest {
    // AC-26: a note of 200 is accepted as typed, a 201st character is cut and reported.
    @Test
    fun noteOfExactlyTheLimitIsKeptWithoutComplaint() {
        val result = FieldRules.cleanInput(TextInput.NOTE, "a".repeat(200))

        assertEquals("a".repeat(200), result.text)
        assertFalse(result.exceededLimit)
    }

    @Test
    fun pastedNoteBeyondTheLimitIsCutAtTheLimitAndReported() {
        val result = FieldRules.cleanInput(TextInput.NOTE, "b".repeat(250))

        assertEquals("b".repeat(200), result.text)
        assertTrue(result.exceededLimit)
    }

    @Test
    fun cuttingCountsCodePointsAndNeverSplitsASurrogatePair() {
        val twoPointsOutsideTheBasicPlane = "🎂🎂"

        val result = FieldRules.cleanInput(TextInput.NOTE, twoPointsOutsideTheBasicPlane + "x", max = 2)

        assertEquals(twoPointsOutsideTheBasicPlane, result.text)
        assertTrue(result.exceededLimit)
    }

    @Test
    fun controlCharactersAreNotInsertedButNewlinesAreKeptWhereAllowed() {
        assertEquals("AnVan", FieldRules.cleanInput(TextInput.NAME, "An\u0007\nVan").text)
        assertEquals("12 Duong\nPhuong", FieldRules.cleanInput(TextInput.ADDRESS, "12 Duong\u0000\nPhuong").text)
        assertEquals("a\nb", FieldRules.cleanInput(TextInput.NOTE, "a\nb").text)
    }

    @Test
    fun blanksAroundTheTextStayWhileTypingButAreTrimmedForSubmit() {
        assertEquals(" An ", FieldRules.cleanInput(TextInput.NAME, " An ").text)
        assertEquals("An", FieldRules.normalizeForSubmit(" An "))
    }

    @Test
    fun decomposedLettersAreCountedAfterNormalisation() {
        val decomposed = "ệ".repeat(60)

        assertEquals(60, FieldRules.lengthOf(decomposed))
        assertEquals("ệ".repeat(60), FieldRules.normalizeForSubmit(decomposed))
    }

    @Test
    fun noteMaxFollowsTheConfiguredValue() {
        assertTrue(FieldRules.isValid(TextInput.NOTE, "a".repeat(300), max = 300))
        assertFalse(FieldRules.isValid(TextInput.NOTE, "a".repeat(301), max = 300))
    }
}
