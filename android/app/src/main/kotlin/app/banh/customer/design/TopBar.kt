package app.banh.customer.design

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.TopAppBarScrollBehavior
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import app.banh.customer.R

@Composable
private fun BackButton(onBack: () -> Unit) {
    IconButton(onClick = onBack) {
        Icon(painter = painterResource(R.drawable.ic_arrow_back), contentDescription = stringResource(R.string.common_back))
    }
}

@Composable
private fun TitleText(title: String, maxLines: Int) {
    Text(title, maxLines = maxLines, overflow = TextOverflow.Ellipsis, modifier = Modifier.semantics { heading() })
}

/**
 * Screen title and back control. The experimental TopAppBar stays inside this function (no experimental type in the
 * signature), so callers need no opt-in; the Material team has kept this component stable in behaviour.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InlineTopBar(title: String, onBack: () -> Unit) {
    TopAppBar(
        title = { TitleText(title, maxLines = 1) },
        navigationIcon = { BackButton(onBack) },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = Color.Transparent,
            scrolledContainerColor = MaterialTheme.colorScheme.surface.copy(alpha = AlphaTokens.SOLID_FALLBACK),
        ),
    )
}

/**
 * Large title that collapses to the inline form on scroll.
 * The scroll behavior type is experimental in Material 3. Marking this function with the same opt-in requirement
 * (instead of hiding it with OptIn) makes each caller state that it accepts the risk; the only caller does so.
 */
@ExperimentalMaterial3Api
@Composable
fun LargeTitleTopBar(title: String, onBack: () -> Unit, scrollBehavior: TopAppBarScrollBehavior? = null) {
    LargeTopAppBar(
        title = { TitleText(title, maxLines = 2) },
        navigationIcon = { BackButton(onBack) },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = Color.Transparent,
            scrolledContainerColor = MaterialTheme.colorScheme.surface.copy(alpha = AlphaTokens.SOLID_FALLBACK),
        ),
        scrollBehavior = scrollBehavior,
    )
}
