package app.banh.customer.testing

import java.io.File

/** Reads the shared contract fixtures; the directory comes from the `contracts.fixtures.dir` property set in app/build.gradle.kts. */
object ContractFixtures {
    private val directory: File = File(
        checkNotNull(System.getProperty("contracts.fixtures.dir")) {
            "contracts.fixtures.dir is set by app/build.gradle.kts"
        },
    )

    fun read(name: String): String = File(directory, name).readText()

    /** Names of the fixtures that start with [prefix] and end with [suffix], such as `catalog-`; empty when none exist yet. */
    fun names(prefix: String, suffix: String = ".json"): List<String> =
        directory.list().orEmpty().filter { it.startsWith(prefix) && it.endsWith(suffix) }.sorted()
}
