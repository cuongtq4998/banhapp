package app.banh.admin.shop

import app.banh.admin.owner.Outcome
import app.banh.admin.owner.OwnerApi
import app.banh.admin.owner.OwnerToast
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.owner.Validation
import app.banh.admin.owner.attempt
import app.banh.core.common.MviViewModel
import app.banh.core.model.ShopInfo

/** S-A11: the four shop fields, saved together (BR-11). The phone is sent in E.164 whatever way the owner typed it. */
class ShopViewModel(initial: ShopState, private val api: OwnerApi, private val store: SettingsViewModel) : MviViewModel<ShopState, ShopIntent, Nothing>(initial) {
    override fun reduce(state: ShopState, intent: ShopIntent) = reduceShop(state, intent)

    override suspend fun handle(intent: ShopIntent) {
        if (intent != ShopIntent.Save || !current.saving) return
        val s = current
        val shop = ShopInfo(s.name.trim(), s.greeting.trim(), checkNotNull(Validation.normalisePhone(s.phone)), s.zalo.trim())
        when (val result = attempt { api.saveShop(shop) }) {
            is Outcome.Ok -> {
                store.reload()
                store.show(OwnerToast.SAVED)
                dispatch(ShopIntent.Saved)
            }
            is Outcome.Failed -> dispatch(ShopIntent.Failed(result.failure))
            Outcome.Ended -> Unit
        }
    }
}
