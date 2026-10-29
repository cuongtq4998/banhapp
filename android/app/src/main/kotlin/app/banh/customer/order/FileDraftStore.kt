package app.banh.customer.order

import java.io.File
import java.io.IOException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

private const val TEMP_SUFFIX = ".tmp"

private val DraftJson = Json { ignoreUnknownKeys = true }

/**
 * Keeps the draft as one JSON file. The file holds personal data, so the caller passes a path in the app's `no_backup`
 * directory (ADR-0011); the manifest also switches cloud backup off.
 */
class FileDraftStore(
    private val file: File,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : DraftStore {
    override suspend fun read(): OrderDraft? = withContext(ioDispatcher) {
        try {
            if (file.exists()) DraftJson.decodeFromString<OrderDraft>(file.readText()) else null
        } catch (e: IOException) {
            null
        } catch (e: SerializationException) {
            // A copy written by another app version may not match the current model.
            null
        } catch (e: IllegalArgumentException) {
            null
        }
    }

    override suspend fun write(draft: OrderDraft) {
        withContext(ioDispatcher) {
            try {
                // Write beside the target and rename, so a killed process never leaves a half-written file.
                val temp = File(file.parentFile, file.name + TEMP_SUFFIX)
                temp.writeText(DraftJson.encodeToString(draft))
                if (!temp.renameTo(file)) temp.delete()
            } catch (e: IOException) {
                // Intentionally ignored, see DraftStore.write.
            }
        }
    }

    override suspend fun clear() {
        withContext(ioDispatcher) { file.delete() }
    }
}
