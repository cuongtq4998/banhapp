package app.banh.admin.owner

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ValidationTest {
    @Test
    fun textMustBeFilledAndNotTooLong() {
        assertEquals(Problem.Required, Validation.text("   ", 10))
        assertEquals(Problem.TooLong(3), Validation.text("abcd", 3))
        assertNull(Validation.text(" abc ", 3))
    }

    @Test
    fun numbersAcceptThousandSeparatorsAndRefuseTheRest() {
        assertNull(Validation.number("1.500.000", 1, 100_000_000))
        assertEquals(Problem.Range(1, 9999), Validation.number("0", 1, 9999))
        assertEquals(Problem.Range(1, 9999), Validation.number("10000", 1, 9999))
        assertEquals(Problem.Range(1, 9999), Validation.number("12a", 1, 9999))
        assertEquals(Problem.Required, Validation.number("", 1, 9999))
    }

    @Test
    fun aVietnameseNumberIsSentInE164() {
        assertEquals("+84912345678", Validation.normalisePhone("0912 345 678"))
        assertEquals("+84912345678", Validation.normalisePhone("84912345678"))
        assertEquals("+84912345678", Validation.normalisePhone("+84 912.345.678"))
        assertNull(Validation.normalisePhone("abc"))
        assertNull(Validation.normalisePhone("123"))
        assertEquals(Problem.Phone, Validation.phone("12345"))
    }

    @Test
    fun emailNeedsAnAtAndADot() {
        assertNull(Validation.email(" a@b.vn "))
        assertEquals(Problem.EmailInvalid, Validation.email("a@b"))
        assertEquals(Problem.Required, Validation.email(""))
    }
}
