package app.banh.customer

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Keeps the package directions of ADR-0018 true with a plain JUnit scan of the `import` lines (Konsist is not verified).
 * A package the test does not know fails it, so new code in a new place forces a decision here.
 *
 * Directions: `data` imports only `data`; `design` imports only `design`, plus the two known couplings in
 * [DESIGN_ROOT_COUPLINGS] that ADR-0018 asks to remove; `order` (flow rules and the store) imports only `data` and
 * itself; `ui` may import every package.
 */
class ImportDirectionTest {
    private val root = File(checkNotNull(System.getProperty("app.sources.dir")) { "set by app/build.gradle.kts" }, "app/banh/customer")

    private val sourceFiles: List<File> = root.walkTopDown().filter { it.isFile && it.extension == "kt" }.toList()

    private fun packageOf(file: File): String = file.relativeTo(root).path.substringBefore(File.separatorChar, missingDelimiterValue = ROOT)

    private fun importsOf(file: File): List<String> = file.readLines()
        .filter { it.startsWith(IMPORT_PREFIX) }
        .map { it.removePrefix(IMPORT_PREFIX).trim() }

    private fun violations(layer: String, allowed: (String) -> Boolean): List<String> = sourceFiles
        .filter { packageOf(it) == layer }
        .flatMap { file -> importsOf(file).filterNot(allowed).map { "${file.name} imports $it" } }

    @Test
    fun sourcesAreFoundAndEveryTopLevelPackageIsKnown() {
        assertTrue("no sources under $root", sourceFiles.isNotEmpty())
        val unknown = sourceFiles.map(::packageOf).toSet() - KNOWN_PACKAGES
        assertEquals("Unknown package: decide its direction in ImportDirectionTest", emptySet<String>(), unknown)
    }

    @Test
    fun dataImportsNothingFromScreensDesignOrOrderFlow() {
        assertEquals(emptyList<String>(), violations("data") { it.startsWith("data.") })
    }

    @Test
    fun designImportsNoDataOrScreensExceptTheKnownCouplings() {
        assertEquals(emptyList<String>(), violations("design") { it.startsWith("design.") || it in DESIGN_ROOT_COUPLINGS })
    }

    @Test
    fun theOrderFlowRulesImportNoDesignOrScreens() {
        assertEquals(emptyList<String>(), violations("order") { it.startsWith("order.") || it.startsWith("data.") })
    }

    companion object {
        private const val IMPORT_PREFIX = "import app.banh.customer."
        private const val ROOT = "(root)"
        private val KNOWN_PACKAGES = setOf(ROOT, "data", "design", "order", "ui")

        /** The generated resource class and the test tags: ADR-0018 asks for design to take both as parameters. */
        private val DESIGN_ROOT_COUPLINGS = setOf("R", "TestTags")
    }
}
