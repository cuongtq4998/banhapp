package app.banh.customer.data.catalog

import kotlinx.serialization.Serializable

/** The last good catalog with what is needed to revalidate it and to judge its age (ADR-0011). */
@Serializable
data class CachedCatalog(
    val catalog: Catalog,
    val etag: String?,
    val fetchedAtEpochMillis: Long,
)

/** Local copy of the catalog. Reading never throws: a missing or damaged copy is simply absent. */
interface CatalogCache {
    suspend fun read(): CachedCatalog?

    /** Best effort: the cache only saves time, so a failed write is not an error. */
    suspend fun write(entry: CachedCatalog)
}
