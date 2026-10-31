package app.banh.customer.ui.common

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import app.banh.customer.R

/** "125.000 ₫" for [amountVnd]; the currency sign comes from the string resources. */
@Composable
fun formatMoney(amountVnd: Long): String = stringResource(R.string.money_format, groupThousands(amountVnd))
