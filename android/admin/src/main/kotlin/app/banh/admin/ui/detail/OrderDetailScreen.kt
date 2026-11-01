package app.banh.admin.ui.detail

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.banh.admin.R
import app.banh.admin.orderdetail.DetailPhase
import app.banh.admin.orderdetail.OrderDetailIntent
import app.banh.admin.orderdetail.OrderDetailState
import app.banh.admin.ui.AdminTags
import app.banh.admin.ui.AdminToast
import app.banh.admin.ui.SecureWindow
import app.banh.admin.ui.textRes
import app.banh.admin.ui.tone
import app.banh.core.design.BackControl
import app.banh.core.design.BanhInlineTopBar
import app.banh.core.design.BanhScreen
import app.banh.core.design.SkeletonBlock
import app.banh.core.design.Spacing
import app.banh.core.design.StateMessage
import app.banh.core.design.StatusBadge

/** S-A4. Stateless: the store's state comes in, intents and the two contact actions go out. */
@Composable
fun OrderDetailScreen(
    state: OrderDetailState,
    serverDate: String?,
    dispatch: (OrderDetailIntent) -> Unit,
    onBack: () -> Unit,
    onCall: (String) -> Unit,
    onZalo: (String) -> Unit,
) {
    SecureWindow()
    Box(Modifier.fillMaxSize()) {
        BanhScreen(
            topBar = {
                BanhInlineTopBar(
                    title = state.orderCode,
                    back = BackControl(painterResource(R.drawable.ic_arrow_back), stringResource(R.string.a_back), AdminTags.NAV_BACK),
                    onBack = onBack,
                    titleTag = AdminTags.DETAIL_CODE,
                    actions = {
                        state.detail?.let { StatusBadge(stringResource(it.status.textRes()), it.status.tone(), Modifier.padding(end = Spacing.lg).testTag(AdminTags.DETAIL_STATUS)) }
                    },
                )
            },
            bottomBar = { if (state.phase == DetailPhase.READY) DetailActionBar(state, dispatch) },
        ) { padding ->
            Column(Modifier.fillMaxSize().padding(padding)) { Body(state, serverDate, dispatch, onBack, onCall, onZalo) }
        }
        AdminToast(
            message = if (state.statusToast) stringResource(R.string.a_status_changed) else null,
            onShown = { dispatch(OrderDetailIntent.ToastShown) },
            haptic = HapticFeedbackType.Confirm,
        )
    }
    if (state.completeDialog) CompleteDialog(state.orderCode, dispatch)
    if (state.cancelSheet) CancelSheet(state, dispatch)
}

@Composable
private fun Body(
    state: OrderDetailState,
    serverDate: String?,
    dispatch: (OrderDetailIntent) -> Unit,
    onBack: () -> Unit,
    onCall: (String) -> Unit,
    onZalo: (String) -> Unit,
) {
    val detail = state.detail
    when {
        state.phase == DetailPhase.LOADING -> Skeleton()
        state.phase == DetailPhase.GONE -> Centered {
            StateMessage(stringResource(R.string.a_order_gone), stringResource(R.string.a_back_to_list), painterResource(R.drawable.ic_error), AdminTags.DETAIL_GONE, AdminTags.DETAIL_BACK_TO_LIST, onRetry = onBack)
        }
        state.phase == DetailPhase.OFFLINE -> Centered {
            StateMessage(stringResource(R.string.a_offline), stringResource(R.string.a_retry), painterResource(R.drawable.ic_error), AdminTags.DETAIL_OFFLINE, AdminTags.DETAIL_RETRY, onRetry = { dispatch(OrderDetailIntent.Load) })
        }
        state.phase == DetailPhase.ERROR || detail == null -> Centered {
            StateMessage(stringResource(R.string.a_err_generic), stringResource(R.string.a_retry), painterResource(R.drawable.ic_error), AdminTags.DETAIL_ERROR, AdminTags.DETAIL_RETRY, onRetry = { dispatch(OrderDetailIntent.Load) })
        }
        else -> Column(
            modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = Spacing.screenMargin, vertical = Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            CustomerCard(detail, onCall = { onCall(detail.customerPhone) }, onZalo = { onZalo(detail.customerPhone) })
            DeliveryCard(detail, serverDate)
            CakesCard(detail)
            detail.note?.takeIf { it.isNotBlank() }?.let { NoteCard(it) }
            ReasonCard(detail)
            HistoryLines(detail)
            // Without a bar (a final status) a conflict message still has to be seen.
            if (!state.hasActions) DetailBannerView(state.banner)
        }
    }
}

@Composable
private fun Skeleton() {
    Column(Modifier.fillMaxSize().padding(Spacing.screenMargin).testTag(AdminTags.DETAIL_SKELETON), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        repeat(3) { SkeletonBlock(Modifier.fillMaxWidth().height(120.dp)) }
    }
}

@Composable
private fun Centered(content: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize().padding(Spacing.screenMargin), contentAlignment = androidx.compose.ui.Alignment.Center) { content() }
}
