package app.banh.admin.ui.orders

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import app.banh.admin.orderlist.OrderListIntent
import app.banh.admin.orderlist.OrderListState
import app.banh.core.design.Spacing

/**
 * S-A3. Stateless: the store's state comes in, intents go out. [staffControls] is true for staff, who have no tab bar, so the
 * number and the account button sit in the header (owner: the tab bar carries the number).
 */
@Composable
fun OrderListScreen(
    state: OrderListState,
    dispatch: (OrderListIntent) -> Unit,
    onOpen: (String) -> Unit,
    staffControls: Boolean,
    onAccount: () -> Unit,
    contentPadding: PaddingValues = PaddingValues(),
    modifier: Modifier = Modifier,
) {
    ResumeEffect { dispatch(OrderListIntent.Resumed(System.currentTimeMillis())) }
    Column(modifier = modifier.statusBarsPadding()) {
        OrdersTitleRow(staffControls, state.unfinishedCount, onAccount)
        Spacer(Modifier.height(Spacing.sm))
        SearchField(state.queryText, state.searchTooShort, { dispatch(OrderListIntent.QueryChanged(it)) }, { dispatch(OrderListIntent.SubmitSearch) })
        Spacer(Modifier.height(Spacing.sm))
        FilterBar(state.filter, state.date, { dispatch(OrderListIntent.SelectFilter(it)) }, { dispatch(OrderListIntent.SelectDate(it)) })
        OrderListBody(state, dispatch, onOpen, contentPadding, Modifier.weight(1f))
    }
}

/** Calls [action] every time the screen comes to the foreground (also the first time). */
@Composable
private fun ResumeEffect(action: () -> Unit) {
    val owner = LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_RESUME) action() }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }
}
