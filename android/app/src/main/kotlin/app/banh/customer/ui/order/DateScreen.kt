package app.banh.customer.ui.order

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.design.ErrorMessage
import app.banh.customer.design.ErrorState
import app.banh.customer.design.GlassCard
import app.banh.customer.design.InfoMessage
import app.banh.customer.design.PrimaryButton
import app.banh.customer.design.SecondaryButton
import app.banh.customer.design.SkeletonBlock
import app.banh.customer.design.Spacing
import app.banh.customer.design.loadingSemantics
import app.banh.customer.order.DateCalendar
import app.banh.customer.order.LoadedAvailability
import app.banh.customer.order.OrderFlowState
import app.banh.customer.order.OrderFlowViewModel
import app.banh.customer.order.OrderIntent
import app.banh.customer.order.toDisplayText
import app.banh.customer.order.toLocalDateOrNull
import java.time.LocalDate

private const val CALENDAR_SKELETON_HEIGHT_DP = 280

@Composable
fun DateRoute(flow: OrderFlowViewModel, onBack: () -> Unit, onNext: () -> Unit) {
    val state by flow.state.collectAsStateWithLifecycle()
    val catalogReady = state.catalog is Load.Ready
    // The answer depends on the total number of cakes, so it is asked each time the step opens, once the cakes are known.
    LaunchedEffect(catalogReady) { if (catalogReady) flow.onIntent(OrderIntent.LoadAvailability) }
    DateScreen(state, flow::onIntent, onBack, onNext)
}

/** S-6, step 2: the receiving date from the server's availability and one time slot (FR-6, FR-7). */
@Composable
fun DateScreen(state: OrderFlowState, onIntent: (OrderIntent) -> Unit, onBack: () -> Unit, onNext: () -> Unit) {
    val availability = (state.availability as? Load.Ready)?.value
    val canProceed = availability != null && state.draft.date != null && state.draft.slotId != null
    OrderStepScaffold(
        step = 2,
        onBack = onBack,
        bottomBar = {
            PrimaryButton(
                text = stringResource(R.string.common_next),
                onClick = onNext,
                modifier = Modifier.testTag(TestTags.ORDER_NEXT),
                enabled = canProceed,
            )
        },
    ) {
        when (val catalog = state.catalog) {
            Load.Loading -> DateSkeleton()
            is Load.Failed -> ErrorState(stringResource(R.string.date_err), onRetry = { onIntent(OrderIntent.RetryCatalog) })
            is Load.Ready ->
                if (catalog.value.slots.isEmpty()) {
                    ErrorState(stringResource(R.string.date_err), onRetry = { onIntent(OrderIntent.RetryCatalog) })
                } else {
                    DateBody(state, catalog.value, onIntent, onBackToQuantity = onBack, canProceed = canProceed)
                }
        }
    }
}

@Composable
private fun DateBody(state: OrderFlowState, catalog: Catalog, onIntent: (OrderIntent) -> Unit, onBackToQuantity: () -> Unit, canProceed: Boolean) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        if (state.dateCleared) {
            ErrorMessage(stringResource(R.string.date_cleared), Modifier.testTag(TestTags.ORDER_DATE_CLEARED))
        }
        when (val availability = state.availability) {
            null, Load.Loading -> DateSkeleton()
            is Load.Failed -> ErrorState(stringResource(R.string.date_err), onRetry = { onIntent(OrderIntent.LoadAvailability) })
            is Load.Ready -> DateCard(state, catalog, availability.value, onIntent, onBackToQuantity)
        }
        GlassCard(Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.time_title), style = MaterialTheme.typography.titleLarge, modifier = Modifier.semantics { heading() })
            SlotList(catalog.slots, state.draft.slotId) { onIntent(OrderIntent.ChooseSlot(it)) }
        }
        if (!canProceed) {
            InfoMessage(stringResource(R.string.next_hint_date_time), Modifier.testTag(TestTags.ORDER_DATE_HINT))
        }
    }
}

@Composable
private fun DateCard(
    state: OrderFlowState,
    catalog: Catalog,
    loaded: LoadedAvailability,
    onIntent: (OrderIntent) -> Unit,
    onBackToQuantity: () -> Unit,
) {
    val settings = catalog.settings
    val serverDate = remember(loaded) { LocalDate.parse(loaded.availability.serverDate) }
    val calendar = remember(loaded) { DateCalendar(serverDate, settings.maxDaysAhead, loaded.availability.dates) }
    GlassCard(Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Text(stringResource(R.string.date_title), style = MaterialTheme.typography.titleLarge, modifier = Modifier.semantics { heading() })
            Text(
                stringResource(
                    R.string.date_hint_range,
                    serverDate.plusDays(settings.leadDays.toLong()).toDisplayText(),
                    serverDate.plusDays(settings.maxDaysAhead.toLong()).toDisplayText(),
                ),
                style = MaterialTheme.typography.bodyLarge,
            )
            DateGrid(calendar, state.draft.date?.toLocalDateOrNull(), DateRules(settings.leadDays, settings.maxDaysAhead)) {
                onIntent(OrderIntent.ChooseDate(it.toString()))
            }
            Text(stringResource(R.string.date_legend_full), style = MaterialTheme.typography.bodySmall)
            if (!calendar.hasSelectableDate) {
                InfoMessage(stringResource(R.string.date_empty), Modifier.testTag(TestTags.ORDER_DATE_EMPTY))
                SecondaryButton(
                    text = stringResource(R.string.date_empty_action),
                    onClick = onBackToQuantity,
                    modifier = Modifier.testTag(TestTags.ORDER_DATE_EMPTY_ACTION),
                )
            }
        }
    }
}

@Composable
private fun DateSkeleton() {
    GlassCard(Modifier.fillMaxWidth().testTag(TestTags.ORDER_DATE_LOADING).loadingSemantics()) {
        SkeletonBlock(Modifier.fillMaxWidth().height(CALENDAR_SKELETON_HEIGHT_DP.dp))
    }
}
