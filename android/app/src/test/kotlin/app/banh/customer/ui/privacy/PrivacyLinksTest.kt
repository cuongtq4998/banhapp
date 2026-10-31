package app.banh.customer.ui.privacy

import org.junit.Assert.assertEquals
import org.junit.Test

/** FR-20: the link goes to `GET <API base URL>/privacy` whatever way the base URL is written. */
class PrivacyLinksTest {
    @Test
    fun baseUrlWithTrailingSlashGetsOneSlash() {
        assertEquals("https://api.example.test/privacy", PrivacyLinks.url("https://api.example.test/"))
    }

    @Test
    fun baseUrlWithoutTrailingSlashGetsOneSlash() {
        assertEquals("https://api.example.test/privacy", PrivacyLinks.url("https://api.example.test"))
    }

    @Test
    fun baseUrlWithAPathKeepsIt() {
        assertEquals("http://10.0.2.2:8080/api/privacy", PrivacyLinks.url("http://10.0.2.2:8080/api/"))
    }
}
