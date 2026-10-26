package app.banh.customer.data.catalog

import app.banh.customer.data.network.ApiException

/** Edge to the backend's catalog endpoint; the repository and the tests depend on this, not on OkHttp. */
interface CatalogApi {
    /**
     * Fetches the catalog, revalidating with [etag] when given.
     * @throws ApiException on every failure.
     */
    suspend fun fetchCatalog(etag: String?): CatalogResponse
}

sealed interface CatalogResponse {
    data class Modified(val catalog: Catalog, val etag: String?) : CatalogResponse

    /** 304: the copy the caller already holds is still current. */
    data object NotModified : CatalogResponse
}
