package app.banh.customer.ui.order

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.design.Sizes
import app.banh.customer.design.Spacing
import app.banh.customer.order.CalendarDay
import app.banh.customer.order.CalendarMonth
import app.banh.customer.order.DateCalendar
import app.banh.customer.order.DateStatus
import java.time.LocalDate

private const val DAYS_IN_WEEK = 7
private const val UNAVAILABLE_ALPHA = 0.4f
private const val SELECTED_BORDER_WIDTH_DP = 2

/** Texts and limits the cells need to speak the reason a day cannot be chosen. */
data class DateRules(val leadDays: Int, val maxDaysAhead: Int)

/**
 * Month calendar for S-6. A custom grid because the system picker cannot mark capacity-based dates unavailable
 * (UI document 2). Unavailable days are not clickable; a full day also has a diagonal strike so colour is not the only
 * cue (UI document 9).
 */
@Composable
fun DateGrid(
    calendar: DateCalendar,
    selected: LocalDate?,
    rules: DateRules,
    onSelect: (LocalDate) -> Unit,
) {
    var monthIndex by rememberSaveable { mutableStateOf(calendar.initialMonthIndex(selected)) }
    val index = monthIndex.coerceIn(0, calendar.months.lastIndex)
    val month = calendar.months[index]
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        MonthHeader(
            month = month,
            previous = calendar.months.getOrNull(index - 1),
            next = calendar.months.getOrNull(index + 1),
            onPrevious = { monthIndex = index - 1 },
            onNext = { monthIndex = index + 1 },
        )
        WeekdayRow()
        weeksOf(month).forEach { week ->
            Row(Modifier.fillMaxWidth()) {
                week.forEach { day ->
                    val cellModifier = Modifier.weight(1f)
                    if (day == null) {
                        Box(cellModifier)
                    } else {
                        DayCell(day, isSelected = day.date == selected, rules = rules, onClick = { onSelect(day.date) }, modifier = cellModifier)
                    }
                }
            }
        }
    }
}

/** Rows of seven cells; null is an empty cell before day 1 or after the last day. */
private fun weeksOf(month: CalendarMonth): List<List<CalendarDay?>> {
    val cells: List<CalendarDay?> = List(month.leadingBlanks) { null } + month.days
    val padded = cells + List((DAYS_IN_WEEK - cells.size % DAYS_IN_WEEK) % DAYS_IN_WEEK) { null }
    return padded.chunked(DAYS_IN_WEEK)
}

@Composable
private fun MonthHeader(
    month: CalendarMonth,
    previous: CalendarMonth?,
    next: CalendarMonth?,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        MonthButton(R.drawable.ic_chevron_left, previous, R.string.date_prev_month, TestTags.ORDER_DATE_PREVIOUS, onPrevious)
        Text(
            text = monthTitle(month.month),
            style = MaterialTheme.typography.titleLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.weight(1f).testTag(TestTags.ORDER_DATE_MONTH),
        )
        MonthButton(R.drawable.ic_chevron_right, next, R.string.date_next_month, TestTags.ORDER_DATE_NEXT, onNext)
    }
}

/** Disabled at the first and last month (UI document 5.6); the label names the month it leads to. */
@Composable
private fun MonthButton(iconRes: Int, target: CalendarMonth?, fallbackLabel: Int, tag: String, onClick: () -> Unit) {
    val label = if (target != null) monthTitle(target.month) else stringResource(fallbackLabel)
    IconButton(onClick = onClick, enabled = target != null, modifier = Modifier.testTag(tag)) {
        Icon(painter = painterResource(iconRes), contentDescription = label)
    }
}

@Composable
private fun WeekdayRow() {
    val names = listOf(
        R.string.date_weekday_1, R.string.date_weekday_2, R.string.date_weekday_3, R.string.date_weekday_4,
        R.string.date_weekday_5, R.string.date_weekday_6, R.string.date_weekday_7,
    )
    Row(Modifier.fillMaxWidth()) {
        names.forEach { name ->
            Text(
                text = stringResource(name),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun DayCell(day: CalendarDay, isSelected: Boolean, rules: DateRules, onClick: () -> Unit, modifier: Modifier) {
    val description = dayDescription(day, isSelected, rules)
    val primary = MaterialTheme.colorScheme.primary
    val strike = MaterialTheme.colorScheme.onSurfaceVariant
    val textColor = MaterialTheme.colorScheme.onSurface.let { if (day.status.selectable) it else it.copy(alpha = UNAVAILABLE_ALPHA) }
    Box(
        modifier = modifier
            .heightIn(min = Sizes.touchTarget)
            .testTag(TestTags.orderDate(day.date.toString()))
            .semantics { contentDescription = description; selected = isSelected }
            .clip(CircleShape)
            .background(if (isSelected) MaterialTheme.colorScheme.primaryContainer else Color.Transparent)
            .then(if (isSelected) Modifier.border(SELECTED_BORDER_WIDTH_DP.dp, primary, CircleShape) else Modifier)
            .clickable(enabled = day.status.selectable, role = Role.Button, onClick = onClick)
            .drawBehind {
                if (day.status == DateStatus.FULL) {
                    drawLine(strike, Offset(0f, size.height), Offset(size.width, 0f), strokeWidth = Sizes.hairline.toPx() * 2)
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Text(day.date.dayOfMonth.toString(), style = MaterialTheme.typography.bodyLarge, color = textColor)
    }
}

@Composable
private fun dayDescription(day: CalendarDay, isSelected: Boolean, rules: DateRules): String {
    val date = spokenDate(day.date)
    return when {
        isSelected -> stringResource(R.string.date_a11y_selected, date)
        day.status == DateStatus.AVAILABLE -> stringResource(R.string.date_a11y_available, date)
        day.status == DateStatus.FULL -> stringResource(R.string.date_a11y_full, date)
        day.status == DateStatus.TOO_SOON -> stringResource(R.string.date_a11y_too_soon, date, rules.leadDays)
        else -> stringResource(R.string.date_a11y_too_far, date, rules.maxDaysAhead)
    }
}
