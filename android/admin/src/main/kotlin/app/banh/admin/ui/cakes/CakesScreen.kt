package app.banh.admin.ui.cakes

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import app.banh.admin.R
import app.banh.admin.cakes.sortedCakes
import app.banh.admin.owner.SettingsState
import app.banh.admin.photo.ImageSource
import app.banh.admin.ui.AdminTags
import app.banh.admin.ui.forms.GatedPage
import app.banh.admin.ui.forms.OwnerToastHost
import app.banh.core.common.formatVnd
import app.banh.core.design.BackControl
import app.banh.core.design.BadgeTone
import app.banh.core.design.BanhInlineTopBar
import app.banh.core.design.BanhScreen
import app.banh.core.design.GlassCard
import app.banh.core.design.InfoMessageView
import app.banh.core.design.PrimaryButton
import app.banh.core.design.Sizes
import app.banh.core.design.Spacing
import app.banh.core.design.StatusBadge
import app.banh.core.model.Cake

/** S-A7: every cake that is not removed, active first, with the add button; at 12 the button is off and the note says why (AC-33). */
@Composable
fun CakesScreen(
    state: SettingsState,
    images: ImageSource,
    onRetry: () -> Unit,
    onBack: () -> Unit,
    onAdd: () -> Unit,
    onOpen: (Cake) -> Unit,
    onToast: () -> Unit,
) {
    GatedPage(stringResource(R.string.a_row_cakes), onBack, state.phase, onRetry) {
        val settings = checkNotNull(state.settings)
        val full = settings.cakes.size >= settings.cakeCountMax
        BanhScreen(
            topBar = {
                BanhInlineTopBar(
                    title = stringResource(R.string.a_row_cakes),
                    back = BackControl(painterResource(R.drawable.ic_arrow_back), stringResource(R.string.a_back), AdminTags.NAV_BACK),
                    onBack = onBack,
                    actions = {
                        Text(stringResource(R.string.a_cakes_count, settings.cakes.size), style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(end = Spacing.lg).testTag(AdminTags.CAKES_COUNT))
                    },
                )
            },
        ) { padding ->
            LazyColumn(
                contentPadding = PaddingValues(start = Spacing.screenMargin, end = Spacing.screenMargin, top = padding.calculateTopPadding() + Spacing.sm, bottom = Spacing.xxl),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
                modifier = Modifier.testTag("admin.cakes.list"),
            ) {
                item { PrimaryButton(stringResource(R.string.a_add_cake), onAdd, Modifier.testTag(AdminTags.CAKES_ADD), enabled = !full) }
                if (full) item { InfoMessageView(stringResource(R.string.a_cakes_full), painterResource(R.drawable.ic_error), Modifier.testTag(AdminTags.CAKES_FULL)) }
                if (settings.cakes.isEmpty()) item { Text(stringResource(R.string.a_cakes_empty), style = MaterialTheme.typography.bodyLarge) }
                items(sortedCakes(settings.cakes), key = { it.cakeId }) { CakeRow(it, images) { onOpen(it) } }
            }
        }
        OwnerToastHost(state.toast, onToast)
    }
}

@Composable
private fun CakeRow(cake: Cake, images: ImageSource, onClick: () -> Unit) {
    GlassCard(onClick = onClick, modifier = Modifier.fillMaxWidth().alpha(if (cake.isActive) 1f else HIDDEN_ALPHA).testTag(AdminTags.cakeRow(cake.cakeId))) {
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md), verticalAlignment = Alignment.CenterVertically) {
            CakeImage(images, cake.imageUrl, Sizes.thumb)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                Text(cake.name, style = MaterialTheme.typography.titleMedium)
                Text(formatVnd(cake.priceVnd), style = MaterialTheme.typography.bodyLarge)
                StatusBadge(stringResource(if (cake.isActive) R.string.a_cake_active else R.string.a_cake_hidden), if (cake.isActive) BadgeTone.CONFIRMED else BadgeTone.COMPLETED)
            }
        }
    }
}

private const val HIDDEN_ALPHA = 0.7f
