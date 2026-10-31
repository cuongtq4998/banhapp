package app.banh.customer.data.catalog

import app.banh.customer.data.network.ApiJson
import java.io.File
import java.io.IOException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

private const val TEMP_SUFFIX = ".tmp"

/** Stores the cache as one JSON file in app-private storage. The catalog is public shop data, not personal data. */
class FileCatalogCache(
    private val file: File,
    private val json: Json = ApiJson,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : CatalogCache {
    override suspend fun read(): CachedCatalog? = withContext(ioDispatcher) {
        try {
            if (file.exists()) json.decodeFromString<CachedCatalog>(file.readText()) else null
        } catch (e: IOException) {
            null
        } catch (e: SerializationException) {
            // A copy written by an older app version may not match the current model.
            null
        } catch (e: IllegalArgumentException) {
            null
        }
    }

    override suspend fun write(entry: CachedCatalog) {
        withContext(ioDispatcher) {
            try {
                // Write beside the target and rename, so a killed process never leaves a half-written file.
                val temp = File(file.parentFile, file.name + TEMP_SUFFIX)
                temp.writeText(json.encodeToString(entry))
                if (!temp.renameTo(file)) temp.delete()
            } catch (e: IOException) {
                // Intentionally ignored, see CatalogCache.write.
            }
        }
    }
}
