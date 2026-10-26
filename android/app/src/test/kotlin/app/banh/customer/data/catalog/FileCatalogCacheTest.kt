package app.banh.customer.data.catalog

import app.banh.customer.testing.TestCatalogs
import java.io.File
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class FileCatalogCacheTest {
    @get:Rule
    val folder = TemporaryFolder()

    private fun cacheFile() = File(folder.root, "catalog-cache.json")

    private val entry get() = CachedCatalog(TestCatalogs.catalog(), "\"v1\"", fetchedAtEpochMillis = 1_000L)

    @Test
    fun missingFileReadsAsNoCache() = runTest {
        assertNull(FileCatalogCache(cacheFile()).read())
    }

    @Test
    fun writtenEntryReadsBackUnchanged() = runTest {
        val cache = FileCatalogCache(cacheFile())

        cache.write(entry)

        assertEquals(entry, cache.read())
    }

    @Test
    fun laterWriteReplacesTheEarlierOne() = runTest {
        val cache = FileCatalogCache(cacheFile())
        cache.write(entry)

        cache.write(entry.copy(etag = "\"v2\""))

        assertEquals("\"v2\"", cache.read()?.etag)
    }

    @Test
    fun damagedFileReadsAsNoCache() = runTest {
        cacheFile().writeText("{ not json")

        assertNull(FileCatalogCache(cacheFile()).read())
    }

    @Test
    fun fileThatDoesNotMatchTheModelReadsAsNoCache() = runTest {
        cacheFile().writeText("""{"catalog":{"server_date":"2026-11-02"},"etag":null,"fetchedAtEpochMillis":1}""")

        assertNull(FileCatalogCache(cacheFile()).read())
    }

    @Test
    fun writeLeavesNoTemporaryFileBehind() = runTest {
        FileCatalogCache(cacheFile()).write(entry)

        assertEquals(listOf("catalog-cache.json"), folder.root.list().orEmpty().toList())
    }

    @Test
    fun writeToAMissingDirectoryDoesNotThrow() = runTest {
        FileCatalogCache(File(folder.root, "absent/catalog-cache.json")).write(entry)
    }
}
