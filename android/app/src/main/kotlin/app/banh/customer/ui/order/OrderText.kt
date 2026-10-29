package app.banh.customer.ui.order

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import app.banh.customer.R
import app.banh.customer.data.catalog.Slot
import java.time.LocalDate
import java.time.YearMonth

/** `08:00 – 10:00` (`SLOT_LABEL`). */
@Composable
fun slotLabel(slot: Slot): String = stringResource(R.string.slot_label, slot.start, slot.end)

/** The date as a screen reader should say it: "ngày 4 tháng 11 năm 2026". */
@Composable
fun spokenDate(date: LocalDate): String =
    stringResource(R.string.date_spoken, date.dayOfMonth, date.monthValue, date.year)

/** "Tháng 11 năm 2026". */
@Composable
fun monthTitle(month: YearMonth): String = stringResource(R.string.date_month_title, month.monthValue, month.year)
