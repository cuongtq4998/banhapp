package app.banh.admin.ui.detail

import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import app.banh.admin.R
import app.banh.admin.orderdetail.BusyAction
import app.banh.admin.orderdetail.DetailSheet
import app.banh.admin.orderdetail.OrderDetailIntent
import app.banh.admin.orderdetail.OrderDetailState
import app.banh.admin.orderdetail.isDayPickable
import app.banh.admin.orderdetail.openingDateOf
import app.banh.admin.orderdetail.sheetError
import app.banh.admin.ui.AdminOrderTags
import app.banh.core.common.formatDate
import app.banh.core.common.formatWeekdayDate
import app.banh.core.design.ErrorMessageView
import app.banh.core.model.DateRange
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import androidx.compose.ui.res.painterResource

private fun LocalDate.toPickerMillis(): Long = atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()

private fun Long.toPickerDay(): String = Instant.ofEpochMilli(this).atZone(ZoneOffset.UTC).toLocalDate().toString()

/** The picker works in UTC midnights; the shop date is plain text, so both sides convert through that. */
@OptIn(ExperimentalMaterial3Api::class)
private class RangeDates(private val range: DateRange?) : SelectableDates {
    override fun isSelectableDate(utcTimeMillis: Long): Boolean = isDayPickable(utcTimeMillis.toPickerDay(), range)

    override fun isSelectableYear(year: Int): Boolean = range == null || year in LocalDate.parse(range.min).year..LocalDate.parse(range.max).year
}

/** Schedule or move the expected date; only the server range is selectable, saving needs a valid, different day. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DateSheet(state: OrderDetailState, serverDate: String?, dispatch: (OrderDetailIntent) -> Unit) {
    val sheet = state.sheet as? DetailSheet.Date ?: return
    val detail = state.detail ?: return
    val range = detail.expectedDateRange
    val opening = remember { openingDateOf(detail) }
    val picker = rememberDatePickerState(
        initialSelectedDateMillis = (sheet.picked ?: opening)?.let { LocalDate.parse(it).toPickerMillis() },
        selectableDates = remember(range) { RangeDates(range) },
    )
    LaunchedEffect(picker) {
        snapshotFlow { picker.selectedDateMillis }.collect { ms -> ms?.toPickerDay()?.let { if (it != sheet.picked) dispatch(OrderDetailIntent.PickDate(it)) } }
    }
    val spec = SheetSpec(
        title = stringResource(if (sheet.change) R.string.a_reschedule_title else R.string.a_schedule_title, state.orderCode),
        sheetTag = AdminOrderTags.SCHEDULE_SHEET,
        saveText = stringResource(if (sheet.change) R.string.a_reschedule_save else R.string.a_schedule_save),
        saveTag = AdminOrderTags.SCHEDULE_SAVE,
        backTag = AdminOrderTags.SCHEDULE_BACK,
        saveEnabled = state.canSaveDate,
        busy = if (sheet.change) BusyAction.CHANGE_DATE else BusyAction.SCHEDULE,
    )
    SheetFrame(state, spec, dispatch) {
        Text(stringResource(R.string.a_requested_date) + ": " + formatWeekdayDate(detail.requestedDeliveryDate ?: detail.deliveryDate, serverDate), style = MaterialTheme.typography.bodyLarge)
        detail.expectedDeliveryDate?.takeIf { sheet.change }?.let {
            Text(stringResource(R.string.a_expected_date) + ": " + formatWeekdayDate(it, serverDate), style = MaterialTheme.typography.bodyLarge)
        }
        sheet.picked?.let { Text(formatWeekdayDate(it, serverDate), style = MaterialTheme.typography.titleMedium) }
        DatePicker(state = picker, title = null, headline = null, showModeToggle = false, colors = DatePickerDefaults.colors(), modifier = Modifier.testTag(AdminOrderTags.SCHEDULE_PICKER))
        range?.let {
            Text(stringResource(R.string.a_date_limit_help, formatDate(it.min, serverDate), formatDate(it.max, serverDate)), style = MaterialTheme.typography.bodySmall, modifier = Modifier.testTag(AdminOrderTags.SCHEDULE_LIMIT))
        }
        Text(stringResource(R.string.a_schedule_help), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        sheet.error?.sheetError()?.let { ErrorMessageView(stringResource(it.textRes()), painterResource(R.drawable.ic_error), Modifier.testTag(AdminOrderTags.SCHEDULE_ERROR)) }
    }
}
