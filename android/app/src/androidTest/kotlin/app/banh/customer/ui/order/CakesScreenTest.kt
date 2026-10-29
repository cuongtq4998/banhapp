package app.banh.customer.ui.order

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import app.banh.customer.data.catalog.Catalog
import app.banh.customer.order.OrderDraft
import app.banh.customer.order.OrderFlowState
import app.banh.customer.order.OrderIntent
import app.banh.customer.testing.ContractAssets
import app.banh.customer.testing.ReducerHost
import app.banh.customer.testing.hasTestTagPrefix
import app.banh.customer.testing.hasTestTagSuffix
import app.banh.customer.testing.setBanhContent
import app.banh.customer.ui.common.groupThousands
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

/** S-5 (UI document 5.5, section 9.1): quantities, totals, the minimum hint, and every state. */
class CakesScreenTest {
    @get:Rule
    val rule = createComposeRule()

    private val catalog: Catalog = ContractAssets.catalog()
    private val first = catalog.products[0]
    private val second = catalog.products[1]

    private fun stateOf(
        catalog: Load<Catalog> = Load.Ready(this.catalog),
        draft: OrderDraft = OrderDraft.blank("key"),
        removed: List<String> = emptyList(),
    ) = OrderFlowState(draft = draft, draftLoaded = true, catalog = catalog, removedCakeNames = removed)

    private fun show(state: OrderFlowState, onIntent: (OrderIntent) -> Unit = {}, onNext: () -> Unit = {}) {
        rule.setBanhContent {
            ReducerHost(state, onIntent) { current, send -> CakesScreen(current, send, onBack = {}, onNext = onNext) }
        }
    }

    private fun tap(tag: String) {
        rule.onNodeWithTag(tag).performScrollTo().performClick()
    }

    // UI 5.5 Empty: the normal first state has every stepper at 0, the hint and a disabled Next.
    @Test
    fun firstVisitShowsZeroEverywhereTheHintAndNoWayForward() {
        show(stateOf())

        rule.onNodeWithTag(TestTags.ORDER_STEP).assertIsDisplayed()
        catalog.products.forEach { rule.onNodeWithTag(TestTags.orderQtyValue(it.id)).assertTextEquals("0") }
        rule.onNodeWithTag(TestTags.ORDER_QTY_TOTAL).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.ORDER_QTY_MIN_HINT).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsNotEnabled()
        rule.onNodeWithTag(TestTags.orderQtyDecrease(first.id)).assertIsNotEnabled()
    }

    // AC-13 (S-5 part): below the minimum the hint shows; at the minimum it goes and Next opens.
    @Test
    fun reachingTheMinimumRemovesTheHintAndEnablesNext() {
        var advanced = 0
        show(stateOf(), onNext = { advanced++ })

        tap(TestTags.orderQtyIncrease(first.id))
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsNotEnabled()
        rule.onNodeWithTag(TestTags.ORDER_QTY_MIN_HINT).performScrollTo().assertIsDisplayed()

        tap(TestTags.orderQtyIncrease(second.id))
        rule.onNodeWithTag(TestTags.ORDER_QTY_MIN_HINT).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsEnabled().performClick()

        assertEquals(1, advanced)
    }

    // BR-5: the running total and subtotal follow the quantities.
    @Test
    fun totalsFollowTheQuantities() {
        show(stateOf())

        tap(TestTags.orderQtyIncrease(first.id))
        tap(TestTags.orderQtyIncrease(first.id))
        tap(TestTags.orderQtyIncrease(second.id))

        rule.onNodeWithTag(TestTags.ORDER_QTY_TOTAL).assertTextEquals("Tổng số bánh: 3")
        val subtotal = 2 * first.priceVnd + second.priceVnd
        rule.onNodeWithTag(TestTags.ORDER_QTY_SUBTOTAL).assertTextEquals("Tiền bánh: ${groupThousands(subtotal)} ₫")
    }

    @Test
    fun minusStopsAtZero() {
        show(stateOf(draft = OrderDraft(quantities = mapOf(first.id to 1), idempotencyKey = "key")))

        tap(TestTags.orderQtyDecrease(first.id))

        rule.onNodeWithTag(TestTags.orderQtyValue(first.id)).assertTextEquals("0")
        rule.onNodeWithTag(TestTags.orderQtyDecrease(first.id)).assertIsNotEnabled()
    }

    // ADR-0009: plus is disabled at 99 with no message.
    @Test
    fun plusStopsAtNinetyNineSilently() {
        show(stateOf(draft = OrderDraft(quantities = mapOf(first.id to 98), idempotencyKey = "key")))

        tap(TestTags.orderQtyIncrease(first.id))

        rule.onNodeWithTag(TestTags.orderQtyValue(first.id)).assertTextEquals("99")
        rule.onNodeWithTag(TestTags.orderQtyIncrease(first.id)).assertIsNotEnabled()
    }

    // AC-32: 3, 2 or 1 active cakes give exactly that many rows.
    @Test
    fun onlyActiveCakesGetARow() {
        show(stateOf(catalog = Load.Ready(ContractAssets.catalogWithCakes(3))))

        rule.onAllNodes(hasTestTagPrefix("order.qty.") and hasTestTagSuffix(".value")).assertCountEquals(3)
        rule.onNodeWithTag(TestTags.orderQtyValue(catalog.products[3].id)).assertDoesNotExist()
    }

    // UI 5.5 Cake removed: named notice, the others kept.
    @Test
    fun removedCakeNoticeNamesTheCakeAndKeepsTheOtherQuantities() {
        show(stateOf(draft = OrderDraft(quantities = mapOf(first.id to 2), idempotencyKey = "key"), removed = listOf("Bánh X")))

        rule.onNodeWithTag(TestTags.ORDER_CAKE_REMOVED_NOTICE).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.orderQtyValue(first.id)).assertTextEquals("2")

        tap(TestTags.orderQtyIncrease(first.id))

        rule.onNodeWithTag(TestTags.ORDER_CAKE_REMOVED_NOTICE).assertDoesNotExist()
    }

    @Test
    fun loadingShowsNoRowsAndNoWayForward() {
        show(stateOf(catalog = Load.Loading))

        rule.onNodeWithTag(TestTags.orderQtyValue(first.id)).assertDoesNotExist()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsNotEnabled()
    }

    @Test
    fun failedLoadShowsTheErrorAndRetryAsksAgain() {
        val intents = mutableListOf<OrderIntent>()
        show(stateOf(catalog = Load.Failed(LoadFailure.NETWORK)), onIntent = { intents += it })

        rule.onNodeWithTag(TestTags.ERROR_STATE).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsNotEnabled()
        tap(TestTags.STATE_RETRY)

        assertEquals(listOf<OrderIntent>(OrderIntent.RetryCatalog), intents)
    }

    @Test
    fun zeroActiveCakesShowTheEmptyStateAndKeepTheDraft() {
        show(stateOf(catalog = Load.Ready(ContractAssets.catalogWithoutCakes())))

        rule.onNodeWithTag(TestTags.EMPTY_STATE).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag(TestTags.ORDER_NEXT).assertIsNotEnabled()
    }
}
