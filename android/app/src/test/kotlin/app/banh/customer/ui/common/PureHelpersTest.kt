package app.banh.customer.ui.common

import app.banh.customer.ui.contact.ContactLinks
import okhttp3.HttpUrl.Companion.toHttpUrl
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class PureHelpersTest {
    @Test
    fun groupsThousandsWithDots() {
        assertEquals("0", groupThousands(0))
        assertEquals("999", groupThousands(999))
        assertEquals("1.000", groupThousands(1_000))
        assertEquals("125.000", groupThousands(125_000))
        assertEquals("1.234.567", groupThousands(1_234_567))
    }

    @Test
    fun refusesNegativeAmounts() {
        assertThrows(IllegalArgumentException::class.java) { groupThousands(-1) }
    }

    @Test
    fun zaloLinkIsTheWebLinkOfAdr0015() {
        assertEquals("https://zalo.me/84900000000", ContactLinks.zaloUrl("84900000000"))
    }

    @Test
    fun zaloLinkEscapesAnythingThatIsNotAPathCharacter() {
        assertEquals("https://zalo.me/a%2Fb", ContactLinks.zaloUrl("a/b"))
    }

    @Test
    fun phoneLinkUsesTheTelScheme() {
        assertEquals("tel:+84900000000", ContactLinks.phoneUri("+84900000000"))
    }

    @Test
    fun imageIsNeverDecodedSmallerThanNeeded() {
        assertEquals(1, sampleSizeFor(sourceWidth = 800, targetWidth = 800))
        assertEquals(1, sampleSizeFor(sourceWidth = 800, targetWidth = 500))
        assertEquals(2, sampleSizeFor(sourceWidth = 800, targetWidth = 400))
        assertEquals(4, sampleSizeFor(sourceWidth = 1_600, targetWidth = 400))
        assertEquals(1, sampleSizeFor(sourceWidth = 100, targetWidth = 400))
    }

    @Test
    fun unknownSizesDecodeAtFullSize() {
        assertEquals(1, sampleSizeFor(sourceWidth = 0, targetWidth = 400))
        assertEquals(1, sampleSizeFor(sourceWidth = 800, targetWidth = 0))
    }

    @Test
    fun imagePathResolvesAgainstTheApiHostAndKeepsItsVersionQuery() {
        val base = "http://api.test/".toHttpUrl()

        assertEquals(
            "http://api.test/assets/images/cake.jpg?v=0123abcd",
            base.resolve("/assets/images/cake.jpg?v=0123abcd").toString(),
        )
    }
}
