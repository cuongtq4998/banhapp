package app.banh.admin.ui.orders

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import app.banh.admin.R
import app.banh.admin.orderlist.MAX_SEARCH_CHARACTERS
import app.banh.admin.ui.AdminTags
import app.banh.core.common.badgeText
import app.banh.core.design.CountBadge
import app.banh.core.design.Spacing

/**
 * Large title; for staff (no tab bar) the red number of orders to deal with and the round account button sit beside it.
 * The number is text, so colour is never the only signal.
 */
@Composable
fun OrdersTitleRow(showStaffControls: Boolean, unfinished: Int, onAccount: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = Spacing.screenMargin),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Text(
            stringResource(R.string.a_orders_title),
            style = MaterialTheme.typography.headlineMedium,
            modifier = Modifier.weight(1f, fill = false).testTag(AdminTags.ORDERS_TITLE).semantics { heading() },
        )
        if (showStaffControls) {
            if (unfinished > 0) {
                val description = stringResource(R.string.a_tab_badge_a11y, unfinished)
                CountBadge(badgeText(unfinished), Modifier.testTag(AdminTags.ORDERS_BADGE).semantics { contentDescription = description })
            }
            Row(Modifier.weight(1f), horizontalArrangement = Arrangement.End) {
                IconButton(onClick = onAccount, modifier = Modifier.testTag(AdminTags.ORDERS_ACCOUNT)) {
                    Icon(painterResource(R.drawable.ic_account), contentDescription = stringResource(R.string.a_account_a11y))
                }
            }
        }
    }
}

/** Search (FR-11): starts at 3 characters or the search key; fewer shows `A_SEARCH_MIN`; the help line shows while focused and empty. */
@Composable
fun SearchField(text: String, tooShort: Boolean, onChange: (String) -> Unit, onSearch: () -> Unit) {
    var focused by remember { mutableStateOf(false) }
    Column(Modifier.padding(horizontal = Spacing.screenMargin)) {
        OutlinedTextField(
            value = text,
            onValueChange = { onChange(it.take(MAX_SEARCH_CHARACTERS)) },
            placeholder = { Text(stringResource(R.string.a_search_placeholder)) },
            leadingIcon = { Icon(painterResource(R.drawable.ic_search), contentDescription = null) },
            trailingIcon = if (text.isNotEmpty()) ({
                IconButton(onClick = { onChange("") }) { Icon(painterResource(R.drawable.ic_close), contentDescription = stringResource(R.string.a_reset)) }
            }) else null,
            singleLine = true,
            isError = tooShort,
            supportingText = when {
                tooShort -> ({ Text(stringResource(R.string.a_search_min), modifier = Modifier.testTag(AdminTags.ORDERS_SEARCH_MIN)) })
                focused && text.isEmpty() -> ({ Text(stringResource(R.string.a_search_hint)) })
                else -> null
            },
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search, autoCorrectEnabled = false),
            keyboardActions = KeyboardActions(onSearch = { onSearch() }),
            modifier = Modifier.fillMaxWidth().onFocusChanged { focused = it.isFocused }.testTag(AdminTags.ORDERS_SEARCH),
        )
    }
}
