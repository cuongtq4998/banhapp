package app.banh.customer.design

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

/**
 * Common layout of the screens: background, optional top bar, optional floating action bar, snackbar.
 * The content receives the padding that keeps it clear of the bars (the bar height is measured, never assumed).
 */
@Composable
fun BanhScreen(
    modifier: Modifier = Modifier,
    topBar: @Composable () -> Unit = {},
    bottomBar: @Composable () -> Unit = {},
    snackbarHost: @Composable () -> Unit = {},
    content: @Composable (PaddingValues) -> Unit,
) {
    AppBackground {
        Scaffold(
            modifier = modifier.fillMaxSize(),
            containerColor = Color.Transparent,
            topBar = topBar,
            bottomBar = bottomBar,
            snackbarHost = snackbarHost,
            content = content,
        )
    }
}

/** Floating bar holding the primary and secondary action of a screen. */
@Composable
fun BottomActionBar(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    GlassCard(
        modifier = modifier
            .navigationBarsPadding()
            .padding(horizontal = Spacing.screenMargin)
            .padding(bottom = Spacing.sm),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm), content = content)
    }
}
