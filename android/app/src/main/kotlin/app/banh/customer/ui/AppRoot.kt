package app.banh.customer.ui

import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import app.banh.customer.AppContainer
import app.banh.customer.design.BanhTheme
import app.banh.customer.design.LocalReduceMotion
import app.banh.customer.design.Motion
import app.banh.customer.ui.common.LocalImageLoader
import app.banh.customer.ui.home.HomeRoute
import app.banh.customer.ui.home.HomeViewModel
import app.banh.customer.ui.launch.LaunchScreen
import app.banh.customer.ui.order.OrderRoutes
import app.banh.customer.ui.order.orderGraph
import app.banh.customer.ui.products.ProductDetailRoute
import app.banh.customer.ui.products.ProductDetailViewModel
import app.banh.customer.ui.products.ProductsRoute
import app.banh.customer.ui.products.ProductsViewModel

private object Routes {
    const val LAUNCH = "launch"
    const val HOME = "home"
    const val PRODUCTS = "products"
    const val PRODUCT_ID_ARG = "productId"
    const val PRODUCT_DETAIL = "products/{$PRODUCT_ID_ARG}"

    fun productDetail(productId: String) = "products/$productId"
}

@Composable
fun AppRoot(container: AppContainer) {
    BanhTheme {
        CompositionLocalProvider(LocalImageLoader provides container.imageLoader) {
            AppNavigation(container, rememberNavController())
        }
    }
}

@Composable
private fun AppNavigation(container: AppContainer, navController: NavHostController) {
    // Screens change by cross-fade; with animations off the fade is the short one (`motion.reduced`).
    val fadeMillis = if (LocalReduceMotion.current) Motion.SHORT_MILLIS else Motion.LONG_MILLIS
    NavHost(
        navController = navController,
        startDestination = Routes.LAUNCH,
        enterTransition = { fadeIn(tween(fadeMillis)) },
        exitTransition = { fadeOut(tween(fadeMillis)) },
        popEnterTransition = { fadeIn(tween(fadeMillis)) },
        popExitTransition = { fadeOut(tween(fadeMillis)) },
    ) {
        composable(Routes.LAUNCH) {
            LaunchScreen(
                startWork = container.catalogRepository.catalog,
                onFinished = {
                    navController.navigate(Routes.HOME) { popUpTo(Routes.LAUNCH) { inclusive = true } }
                },
            )
        }
        composable(Routes.HOME) {
            HomeRoute(
                viewModel = viewModelOf { HomeViewModel(container.catalogRepository) },
                onViewProducts = { navController.navigate(Routes.PRODUCTS) },
                // The saved draft comes back with its quantities; no prompt (UI document 5.5, ADR-0011).
                onPlaceOrder = { navController.navigate(OrderRoutes.cakes()) },
            )
        }
        composable(Routes.PRODUCTS) {
            ProductsRoute(
                viewModel = viewModelOf { ProductsViewModel(container.catalogRepository) },
                onBack = { navController.popBackStack() },
                onOpenProduct = { navController.navigate(Routes.productDetail(it)) },
            )
        }
        composable(Routes.PRODUCT_DETAIL) { entry ->
            val productId = checkNotNull(entry.arguments?.getString(Routes.PRODUCT_ID_ARG)) { "Route always carries the product id" }
            ProductDetailRoute(
                viewModel = viewModelOf { ProductDetailViewModel(container.catalogRepository, productId) },
                onBack = { navController.popBackStack() },
                // A new draft with this cake at quantity 1 (FR-4, AC-5).
                onOrder = { navController.navigate(OrderRoutes.cakes(productId)) },
            )
        }
        orderGraph(
            navController,
            container.orderDependencies,
            // Back to S-2 with everything above it gone, the order graph and its store included.
            onFinished = { navController.popBackStack(Routes.HOME, inclusive = false) },
        )
    }
}

// The view model lives as long as the back stack entry it is created in, so the detail of each cake has its own.
@Composable
private inline fun <reified VM : ViewModel> viewModelOf(crossinline create: () -> VM): VM =
    viewModel<VM>(factory = viewModelFactory { initializer { create() } })
