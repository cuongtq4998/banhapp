package app.banh.admin.ui.orders

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import app.banh.admin.R
import app.banh.admin.orderlist.ListPhase
import app.banh.admin.orderlist.OrderListIntent
import app.banh.admin.orderlist.OrderListState
import app.banh.admin.ui.AdminTags
import app.banh.core.design.SecondaryButton
import app.banh.core.design.Spacing
import app.banh.core.design.StateMessage
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter

private const val LOAD_AHEAD_ROWS = 5

/** Everything below the chips: skeletons, rows with paging, or one of the empty, error and offline states (S-A3 States). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OrderListBody(state: OrderListState, dispatch: (OrderListIntent) -> Unit, onOpen: (String) -> Unit, contentPadding: PaddingValues, modifier: Modifier = Modifier) {
    PullToRefreshBox(isRefreshing = state.refreshing, onRefresh = { dispatch(OrderListIntent.Refresh) }, modifier = modifier) {
        when {
            state.phase == ListPhase.LOADING -> Scrolling { OrderRowSkeletons(Modifier.fillMaxWidth()) }
            state.phase == ListPhase.OFFLINE -> Scrolling { Failure(stringResource(R.string.a_offline), AdminTags.ORDERS_OFFLINE, dispatch) }
            state.phase == ListPhase.ERROR -> Scrolling { Failure(stringResource(R.string.a_err_generic), AdminTags.ORDERS_ERROR, dispatch) }
            state.rows.isEmpty() -> Scrolling { Empty(state, dispatch) }
            else -> Rows(state, dispatch, onOpen, contentPadding)
        }
    }
}

@Composable
private fun Scrolling(content: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding16()) { content() }
}

private fun Modifier.padding16() = this.then(Modifier.padding(horizontal = Spacing.screenMargin, vertical = Spacing.md))

@Composable
private fun Failure(message: String, tag: String, dispatch: (OrderListIntent) -> Unit) {
    StateMessage(message, stringResource(R.string.a_retry), painterResource(R.drawable.ic_error), tag, AdminTags.ORDERS_RETRY, onRetry = { dispatch(OrderListIntent.Refresh) })
}

@Composable
private fun Empty(state: OrderListState, dispatch: (OrderListIntent) -> Unit) {
    val text = when {
        state.searchText.isNotEmpty() -> R.string.a_search_empty
        state.hasFilters -> R.string.a_orders_empty
        else -> R.string.a_todo_empty
    }
    Column(Modifier.fillMaxWidth().testTag(AdminTags.ORDERS_EMPTY), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        Text(stringResource(text), style = MaterialTheme.typography.bodyLarge, textAlign = TextAlign.Center)
        if (state.hasFilters) SecondaryButton(stringResource(R.string.a_clear_filters), { dispatch(OrderListIntent.ClearFilters) }, Modifier.testTag(AdminTags.ORDERS_CLEAR_FILTERS))
    }
}

@Composable
private fun Rows(state: OrderListState, dispatch: (OrderListIntent) -> Unit, onOpen: (String) -> Unit, contentPadding: PaddingValues) {
    val listState = rememberLazyListState()
    // Reaching the last 5 rows loads the next 50 (AC-23).
    LaunchedEffect(listState, state.rows.size) {
        snapshotFlow { listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0 }
            .filter { it >= state.rows.size - LOAD_AHEAD_ROWS }
            .distinctUntilChanged()
            .collect { dispatch(OrderListIntent.LoadMore) }
    }
    LazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize().testTag(AdminTags.ORDERS_LIST),
        contentPadding = PaddingValues(start = Spacing.screenMargin, end = Spacing.screenMargin, top = Spacing.md, bottom = contentPadding.calculateBottomPadding() + Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        items(state.rows, key = { it.orderCode }) { OrderRow(it, state.serverDate, onClick = { onOpen(it.orderCode) }) }
        item(key = "footer") { Footer(state, dispatch) }
    }
}

@Composable
private fun Footer(state: OrderListState, dispatch: (OrderListIntent) -> Unit) {
    when {
        state.loadingMore -> Box(Modifier.fillMaxWidth(), Alignment.Center) { CircularProgressIndicator() }
        state.loadMoreFailed -> Column(Modifier.fillMaxWidth().testTag(AdminTags.ORDERS_LOAD_MORE_ERROR), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(stringResource(R.string.a_load_more_failed), style = MaterialTheme.typography.bodyMedium)
            TextButton(onClick = { dispatch(OrderListIntent.LoadMore) }) { Text(stringResource(R.string.a_retry)) }
        }
    }
}
