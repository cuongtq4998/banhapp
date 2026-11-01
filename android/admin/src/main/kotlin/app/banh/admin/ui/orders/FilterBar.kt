package app.banh.admin.ui.orders

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import app.banh.admin.R
import app.banh.admin.orders.DateFilter
import app.banh.admin.orders.StatusFilter
import app.banh.admin.ui.AdminTags
import app.banh.core.common.formatDayMonth
import androidx.compose.ui.graphics.Color
import app.banh.core.design.AdminSizes
import app.banh.core.design.AlphaTokens
import app.banh.core.design.ColorTokens
import app.banh.core.design.Spacing

private fun StatusFilter.labelRes(): Int = when (this) {
    StatusFilter.TODO -> R.string.a_filter_todo
    StatusFilter.NEW -> R.string.a_status_new
    StatusFilter.CONFIRMED -> R.string.a_status_confirmed
    StatusFilter.COMPLETED -> R.string.a_status_completed
    StatusFilter.CANCELLED -> R.string.a_status_cancelled
    StatusFilter.ALL -> R.string.a_filter_all
}

private fun StatusFilter.tag(): String = when (this) {
    StatusFilter.TODO -> AdminTags.FILTER_TODO
    StatusFilter.NEW -> AdminTags.FILTER_NEW
    StatusFilter.CONFIRMED -> AdminTags.FILTER_CONFIRMED
    StatusFilter.COMPLETED -> AdminTags.FILTER_COMPLETED
    StatusFilter.CANCELLED -> AdminTags.FILTER_CANCELLED
    StatusFilter.ALL -> AdminTags.FILTER_ALL
}

/** One control row (FR-10): exactly one status chip is selected, then the date chip with its menu. */
@Composable
fun FilterBar(selected: StatusFilter, date: DateFilter, serverDate: String?, onStatus: (StatusFilter) -> Unit, onDate: (DateFilter) -> Unit) {
    val groupLabel = stringResource(R.string.a_chip_group_a11y)
    // Seven chips: a plain scrolling row keeps all of them in the semantics tree (a lazy row would drop the off-screen ones).
    Row(
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        modifier = Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = Spacing.screenMargin).semantics { contentDescription = groupLabel },
    ) {
        StatusFilter.entries.forEach { filter ->
            Chip(stringResource(filter.labelRes()), filter == selected, Modifier.testTag(filter.tag())) { onStatus(filter) }
        }
        DateChip(date, serverDate, onDate)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Chip(text: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(text, style = MaterialTheme.typography.labelLarge) },
        modifier = modifier.defaultMinSize(minHeight = AdminSizes.chipHeight),
        // Glass chips: translucent white with a hairline, like the cards (design system); the selected one is solid brand colour.
        border = FilterChipDefaults.filterChipBorder(
            enabled = true,
            selected = selected,
            borderColor = Color(ColorTokens.SURFACE_STROKE).copy(alpha = AlphaTokens.STROKE),
            selectedBorderColor = Color.Transparent,
        ),
        colors = FilterChipDefaults.filterChipColors(
            containerColor = Color(ColorTokens.SURFACE_GLASS).copy(alpha = AlphaTokens.GLASS_SURFACE),
            selectedContainerColor = MaterialTheme.colorScheme.primary,
            selectedLabelColor = MaterialTheme.colorScheme.onPrimary,
        ),
    )
}

@Composable
private fun DateChip(date: DateFilter, serverDate: String?, onDate: (DateFilter) -> Unit) {
    var menu by remember { mutableStateOf(false) }
    var picker by remember { mutableStateOf(false) }
    val label = when (date) {
        DateFilter.Any -> stringResource(R.string.a_filter_date)
        DateFilter.Today -> stringResource(R.string.a_date_today)
        DateFilter.Tomorrow -> stringResource(R.string.a_date_tomorrow)
        is DateFilter.One -> formatDayMonth(date.date)
    }
    Box {
        Chip(label, date != DateFilter.Any, Modifier.testTag(AdminTags.FILTER_DATE)) { menu = true }
        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
            MenuItem(R.string.a_date_all, AdminTags.DATE_ALL) { menu = false; onDate(DateFilter.Any) }
            MenuItem(R.string.a_date_today, AdminTags.DATE_TODAY) { menu = false; onDate(DateFilter.Today) }
            MenuItem(R.string.a_date_tomorrow, AdminTags.DATE_TOMORROW) { menu = false; onDate(DateFilter.Tomorrow) }
            MenuItem(R.string.a_date_one, AdminTags.DATE_ONE) { menu = false; picker = true }
        }
    }
    if (picker) OneDatePicker(serverDate, onDismiss = { picker = false }, onPicked = { picker = false; onDate(DateFilter.One(it)) })
}

@Composable
private fun MenuItem(text: Int, tag: String, onClick: () -> Unit) {
    DropdownMenuItem(text = { Text(stringResource(text)) }, onClick = onClick, modifier = Modifier.testTag(tag))
}
