package app.banh.customer.testing

import androidx.compose.ui.graphics.ImageBitmap
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.data.catalog.CatalogRepository
import app.banh.customer.ui.common.ImageLoader
import app.banh.customer.ui.contact.ContactLauncher
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** A catalog that a test drives by hand; no network, no cache. */
class FakeCatalogRepository(initial: Load<Catalog> = Load.Loading) : CatalogRepository {
    private val state = MutableStateFlow(initial)
    override val catalog: StateFlow<Load<Catalog>> = state

    /** Runs inside [refresh], to script what the next answer of the shop is. */
    var onRefresh: () -> Unit = {}

    fun emit(value: Load<Catalog>) {
        state.value = value
    }

    override suspend fun refresh() = onRefresh()
}

private const val PLACEHOLDER_BITMAP_SIZE = 1

/** Answers every picture with a one-pixel bitmap, except the paths in [failingPaths], which cannot be shown. */
class FakeImageLoader(private val failingPaths: Set<String> = emptySet()) : ImageLoader {
    override suspend fun load(path: String, maxWidthPx: Int): ImageBitmap? =
        if (path in failingPaths) null else ImageBitmap(PLACEHOLDER_BITMAP_SIZE, PLACEHOLDER_BITMAP_SIZE)
}

/** Records what the customer asked to open and answers with a fixed result. */
class RecordingContactLauncher(private val opens: Boolean = true) : ContactLauncher {
    val zaloContacts = mutableListOf<String>()
    val phoneContacts = mutableListOf<String>()

    override fun openZalo(zaloContact: String): Boolean {
        zaloContacts += zaloContact
        return opens
    }

    override fun openPhone(phoneContact: String): Boolean {
        phoneContacts += phoneContact
        return opens
    }
}
