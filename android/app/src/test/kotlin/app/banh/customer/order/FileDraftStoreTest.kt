package app.banh.customer.order

import java.io.File
import java.time.Instant
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class FileDraftStoreTest {
    @get:Rule
    val folder = TemporaryFolder()

    private val draft = OrderDraft(
        quantities = mapOf("product-1" to 2),
        date = "2026-11-06",
        slotId = "slot-1",
        name = "An",
        phone = "0912345678",
        address = "12 Duong Hoa Sen",
        districtId = "district-1",
        note = "Giao sang",
        idempotencyKey = "key-1",
        savedAtEpochMillis = 1_000L,
    )

    private fun store(name: String = "draft.json") = FileDraftStore(File(folder.root, name))

    @Test
    fun aMissingFileIsNoDraft() = runTest {
        assertNull(store().read())
    }

    // FR-15, ADR-0011: every field survives a restart.
    @Test
    fun aWrittenDraftComesBackWithEveryField() = runTest {
        store().write(draft)

        assertEquals(draft, store().read())
    }

    @Test
    fun anOlderCopyIsReplacedNotMerged() = runTest {
        store().write(draft)
        store().write(draft.copy(name = "Binh"))

        assertEquals("Binh", store().read()?.name)
        assertFalse(File(folder.root, "draft.json.tmp").exists())
    }

    @Test
    fun aDamagedFileIsNoDraft() = runTest {
        File(folder.root, "draft.json").writeText("{ not json")

        assertNull(store().read())
    }

    @Test
    fun clearRemovesTheFile() = runTest {
        store().write(draft)

        store().clear()

        assertNull(store().read())
    }

    @Test
    fun unknownFieldsOfANewerVersionAreIgnored() = runTest {
        File(folder.root, "draft.json").writeText("""{"idempotencyKey":"k","fromTheFuture":1}""")

        assertEquals("k", store().read()?.idempotencyKey)
    }

    // ADR-0011: a draft nobody touched for 24 hours is discarded.
    @Test
    fun aDraftIsFreshForExactlyTwentyFourHours() {
        val savedAt = Instant.parse("2026-11-02T03:00:00Z")
        val saved = draft.copy(savedAtEpochMillis = savedAt.toEpochMilli())

        assertTrue(saved.isFresh(savedAt.plus(DRAFT_MAX_AGE)))
        assertFalse(saved.isFresh(savedAt.plus(DRAFT_MAX_AGE).plusSeconds(1)))
    }
}
