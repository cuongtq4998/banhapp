package app.banh.admin.ui

import androidx.compose.runtime.Composable
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import app.banh.admin.AdminContainer
import app.banh.admin.auth.SessionState
import app.banh.admin.ui.detail.DetailRoute

private const val ORDERS = "orders"
private const val ORDER = "order/{code}"
private const val CODE_ARGUMENT = "code"

/** The signed-in app: the order list (staff: alone; owner: with the tab bar), and the order detail pushed over it. */
@Composable
fun SignedInRoot(container: AdminContainer, signedIn: SessionState.SignedIn) {
    val navigation = rememberNavController()
    NavHost(navController = navigation, startDestination = ORDERS) {
        composable(ORDERS) {
            OrdersHome(container, signedIn, onOpenOrder = { navigation.navigate("order/$it") })
        }
        composable(ORDER, arguments = listOf(navArgument(CODE_ARGUMENT) { type = NavType.StringType })) { entry ->
            DetailRoute(container, requireNotNull(entry.arguments?.getString(CODE_ARGUMENT)), onBack = { navigation.popBackStack() })
        }
    }
}
