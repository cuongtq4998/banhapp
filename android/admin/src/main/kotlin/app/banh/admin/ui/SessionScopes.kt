package app.banh.admin.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.viewmodel.compose.LocalViewModelStoreOwner
import androidx.lifecycle.viewmodel.compose.viewModel

/**
 * Holds one `ViewModelStore` per sign-in period, outside the composition so that a rotation keeps the screens' state, and drops
 * the old one when the period ends: nothing a signed-in screen held (orders, names, phone numbers) outlives sign-out (BR-7).
 */
class SessionScopes : ViewModel() {
    private val stores = HashMap<String, ViewModelStore>()

    fun storeFor(key: String): ViewModelStore {
        stores.keys.filter { it != key }.forEach { stores.remove(it)?.clear() }
        return stores.getOrPut(key) { ViewModelStore() }
    }

    override fun onCleared() {
        stores.values.forEach { it.clear() }
        stores.clear()
    }
}

/** Runs [content] with its own view model store for [key]; a new key means fresh view models and the old ones are cleared. */
@Composable
fun SessionScope(key: String, content: @Composable () -> Unit) {
    val store = viewModel<SessionScopes>().storeFor(key)
    val owner = object : ViewModelStoreOwner {
        override val viewModelStore: ViewModelStore = store
    }
    CompositionLocalProvider(LocalViewModelStoreOwner provides owner, content = content)
}
