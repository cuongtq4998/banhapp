package app.banh.customer.ui.order

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.composable
import androidx.navigation.compose.navigation
import androidx.navigation.navArgument
import app.banh.customer.order.OrderDependencies
import app.banh.customer.order.OrderFlowViewModel

/** Routes of the order flow, S-5 to S-9. The graph owns the [OrderFlowViewModel]; its steps share it (FR-15). */
object OrderRoutes {
    const val GRAPH = "order"
    const val PRODUCT_ID_ARG = "productId"
    const val CAKES = "order/cakes?$PRODUCT_ID_ARG={$PRODUCT_ID_ARG}"
    const val DATE = "order/date"
    const val RECIPIENT = "order/recipient"
    const val REVIEW = "order/review"
    const val CONFIRMATION = "order/confirmation"

    /** Opens S-5 with the saved draft, or, with [productId], with a new draft holding that cake at 1 (FR-4, AC-5). */
    fun cakes(productId: String? = null): String =
        if (productId == null) "order/cakes" else "order/cakes?$PRODUCT_ID_ARG=$productId"
}

/**
 * Adds the order graph to [NavGraphBuilder]. The steps move forward with Next and back with the back control; Edit on
 * the review returns to the step in the stack, so every entry made on the way is still there (AC-18).
 */
fun NavGraphBuilder.orderGraph(navController: NavHostController, dependencies: OrderDependencies, onFinished: () -> Unit = {}) {
    navigation(startDestination = OrderRoutes.CAKES, route = OrderRoutes.GRAPH) {
        composable(
            route = OrderRoutes.CAKES,
            arguments = listOf(
                navArgument(OrderRoutes.PRODUCT_ID_ARG) {
                    type = NavType.StringType
                    nullable = true
                    defaultValue = null
                },
            ),
        ) { entry ->
            val flow = rememberOrderFlow(navController, entry, dependencies)
            StartOrderOnce(flow, entry.arguments?.getString(OrderRoutes.PRODUCT_ID_ARG))
            CakesRoute(flow, onBack = { navController.popBackStack() }, onNext = { navController.navigate(OrderRoutes.DATE) })
        }
        composable(OrderRoutes.DATE) { entry ->
            DateRoute(
                flow = rememberOrderFlow(navController, entry, dependencies),
                onBack = { navController.popBackStack() },
                onNext = { navController.navigate(OrderRoutes.RECIPIENT) },
            )
        }
        composable(OrderRoutes.RECIPIENT) { entry ->
            RecipientRoute(
                flow = rememberOrderFlow(navController, entry, dependencies),
                onBack = { navController.popBackStack() },
                onNext = { navController.navigate(OrderRoutes.REVIEW) },
            )
        }
        composable(OrderRoutes.REVIEW) { entry ->
            ReviewRoute(
                flow = rememberOrderFlow(navController, entry, dependencies),
                actions = ReviewActions(
                    onBack = { navController.popBackStack() },
                    onEditCakes = { navController.popBackStack(OrderRoutes.CAKES, inclusive = false) },
                    onEditDelivery = { navController.popBackStack(OrderRoutes.DATE, inclusive = false) },
                    onEditRecipient = { navController.popBackStack(OrderRoutes.RECIPIENT, inclusive = false) },
                    // S-8 leaves the stack, so no back path returns to it and a second send is impossible (UI document 5.9).
                    onConfirmed = {
                        navController.navigate(OrderRoutes.CONFIRMATION) { popUpTo(OrderRoutes.REVIEW) { inclusive = true } }
                    },
                ),
            )
        }
        composable(OrderRoutes.CONFIRMATION) { entry ->
            ConfirmationRoute(flow = rememberOrderFlow(navController, entry, dependencies), onHome = onFinished)
        }
    }
}

// One store for the whole graph: it is looked up on the graph's own back stack entry, not on the step's.
@Composable
private fun rememberOrderFlow(navController: NavHostController, entry: NavBackStackEntry, dependencies: OrderDependencies): OrderFlowViewModel {
    val graphEntry = remember(entry) { navController.getBackStackEntry(OrderRoutes.GRAPH) }
    return viewModel(
        viewModelStoreOwner = graphEntry,
        factory = viewModelFactory { initializer { OrderFlowViewModel(dependencies) } },
    )
}

// The flow opens once per visit. The flag is saved so that a restored screen does not wipe the draft again.
@Composable
private fun StartOrderOnce(flow: OrderFlowViewModel, productId: String?) {
    var started by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        if (!started) {
            started = true
            flow.start(productId)
        }
    }
}
