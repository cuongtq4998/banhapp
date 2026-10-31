package app.banh.customer.testing

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.ComposeContentTestRule
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.findRootCoordinates
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.Density
import app.banh.customer.design.BanhTheme
import app.banh.customer.ui.common.ImageLoader
import app.banh.customer.ui.common.LocalImageLoader
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue

/** Shows [content] inside the app theme with the fake picture loader, as `AppRoot` does with the real one. */
fun ComposeContentTestRule.setBanhContent(imageLoader: ImageLoader = FakeImageLoader(), content: @Composable () -> Unit) {
    setContent {
        BanhTheme {
            CompositionLocalProvider(LocalImageLoader provides imageLoader, content = content)
        }
    }
}

/** No enlargement: the font scale of a device with default settings. */
const val DEFAULT_FONT_SCALE = 1f

/** The largest font scale of the system settings, used to check that text still fits. */
const val LARGEST_FONT_SCALE = 2f

/** Same screen, same density, text enlarged by [fontScale]. */
@Composable
fun WithFontScale(fontScale: Float, content: @Composable () -> Unit) {
    val density = LocalDensity.current
    CompositionLocalProvider(LocalDensity provides Density(density.density, fontScale), content = content)
}

/** Matches every node whose tag starts with [prefix], such as all cards of the list. */
fun hasTestTagPrefix(prefix: String): SemanticsMatcher = SemanticsMatcher("test tag starts with $prefix") {
    it.config.getOrNull(SemanticsProperties.TestTag)?.startsWith(prefix) == true
}

/** Matches every node whose tag ends with [suffix], such as the value of every stepper. */
fun hasTestTagSuffix(suffix: String): SemanticsMatcher = SemanticsMatcher("test tag ends with $suffix") {
    it.config.getOrNull(SemanticsProperties.TestTag)?.endsWith(suffix) == true
}

/**
 * Asserts that no text at or under the element tagged [tag] is cut off: no line ends in an ellipsis, the text is not
 * taller than the space it was given, and the element lies inside the window. Reads the text layout, so it fails when a
 * large font makes a label overflow even if the element is still on screen.
 *
 * `TextLayoutResult.hasVisualOverflow` is not used: on the API 36 emulator `didOverflowWidth` was true for one-line
 * labels that fit with room to spare (a 439 px text in 890 px), so it would fail screens that are fine.
 */
fun ComposeContentTestRule.assertTextNotClipped(tag: String) {
    val hasTextLayout = SemanticsMatcher.keyIsDefined(SemanticsActions.GetTextLayoutResult)
    val ownOrNested = hasTestTag(tag) or hasAnyAncestor(hasTestTag(tag))
    val nodes = onAllNodes(ownOrNested and hasTextLayout, useUnmergedTree = true).fetchSemanticsNodes()
    assertTrue("No text found at $tag", nodes.isNotEmpty())
    nodes.forEach { node ->
        val layouts = mutableListOf<TextLayoutResult>()
        val read = node.config[SemanticsActions.GetTextLayoutResult].action
        assertTrue("Text layout of $tag is not readable", read?.invoke(layouts) == true)
        layouts.forEach { layout ->
            val text = layout.layoutInput.text.text
            assertTrue("Text at $tag is ellipsized: $text", (0 until layout.lineCount).none(layout::isLineEllipsized))
            assertFalse("Text at $tag is taller than its space: $text", layout.didOverflowHeight)
        }
        val window = node.boundsInWindow
        val root = node.layoutInfo.coordinates.findRootCoordinates().boundsInWindow()
        assertTrue("Text at $tag leaves the window: $window in $root", window.left >= root.left && window.top >= root.top && window.right <= root.right && window.bottom <= root.bottom)
    }
}
