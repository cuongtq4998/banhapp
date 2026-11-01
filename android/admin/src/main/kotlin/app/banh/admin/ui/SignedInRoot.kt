package app.banh.admin.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import app.banh.admin.AdminContainer
import app.banh.admin.auth.SessionState
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.ui.account.OwnerArea
import app.banh.admin.ui.cakes.CakeFormRoute
import app.banh.admin.ui.cakes.CakesScreen
import app.banh.admin.ui.delivery.DeliveryRoute
import app.banh.admin.ui.detail.DetailRoute
import app.banh.admin.ui.push.PushEffects
import app.banh.admin.ui.rules.RulesRoute
import app.banh.admin.ui.shop.ShopRoute
import app.banh.admin.ui.staff.StaffRoute
import app.banh.core.model.Role

private const val ORDERS = "orders"
private const val ORDER = "order/{code}"
private const val CODE_ARGUMENT = "code"
private const val CAKES = "cakes"
private const val CAKE_NEW = "cake/new"
private const val CAKE = "cake/{id}"
private const val ID_ARGUMENT = "id"

private fun OwnerArea.route() = when (this) {
    OwnerArea.CAKES -> CAKES
    OwnerArea.RULES -> "rules"
    OwnerArea.DELIVERY -> "delivery"
    OwnerArea.SHOP -> "shop"
    OwnerArea.STAFF -> "staff"
}

/**
 * The signed-in app: the order list (staff alone, owner with the tab bar), the order detail over it, and for the owner the settings
 * areas S-A7 to S-A12. The owner's shared settings store lives here, so it is dropped with the sign-in period (BR-7).
 */
@Composable
fun SignedInRoot(container: AdminContainer, signedIn: SessionState.SignedIn) {
    val navigation = rememberNavController()
    val isOwner = signedIn.account.role == Role.OWNER
    val store = if (isOwner) viewModel<SettingsViewModel>(key = "owner-store", factory = viewModelFactory { initializer { SettingsViewModel(container.owner) } }) else null
    NavHost(navController = navigation, startDestination = ORDERS) {
        composable(ORDERS) {
            OrdersHome(container, signedIn, store, onOpenOrder = { navigation.navigate("order/$it") }, onOpenArea = { navigation.navigate(it.route()) })
        }
        composable(ORDER, arguments = listOf(navArgument(CODE_ARGUMENT) { type = NavType.StringType })) { entry ->
            DetailRoute(container, requireNotNull(entry.arguments?.getString(CODE_ARGUMENT)), onBack = { navigation.popBackStack() })
        }
        if (store != null) ownerRoutes(navigation, container, store)
    }
    PushEffects(container, signedIn.id, onOpenOrder = { navigation.navigate("order/$it") })
}

private fun androidx.navigation.NavGraphBuilder.ownerRoutes(navigation: NavHostController, container: AdminContainer, store: SettingsViewModel) {
    val back: () -> Unit = { navigation.popBackStack() }
    composable(CAKES) {
        val state by store.state.collectAsStateWithLifecycle()
        CakesScreen(state, container.images, store::reload, back, onAdd = { navigation.navigate(CAKE_NEW) }, onOpen = { navigation.navigate("cake/${it.cakeId}") }, onToast = store::toastShown)
    }
    composable(CAKE_NEW) { CakeFormRoute(container, store, null, back) }
    composable(CAKE, arguments = listOf(navArgument(ID_ARGUMENT) { type = NavType.StringType })) { entry ->
        CakeFormRoute(container, store, requireNotNull(entry.arguments?.getString(ID_ARGUMENT)), back)
    }
    composable("rules") { RulesRoute(container, store, back) }
    composable("delivery") { DeliveryRoute(container, store, back) }
    composable("shop") { ShopRoute(container, store, back) }
    composable("staff") { StaffRoute(container, store, back) }
}
