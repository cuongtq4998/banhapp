package app.banh.admin.shop

import app.banh.admin.owner.Limits
import app.banh.admin.owner.OwnerFailure
import app.banh.admin.owner.Problem
import app.banh.admin.owner.Validation
import app.banh.admin.owner.problems
import app.banh.admin.owner.problemsOf
import app.banh.core.model.ShopInfo

const val SHOP_NAME_MAX = 100
const val GREETING_MAX = 300
const val ZALO_MIN = 3
const val ZALO_MAX = 100

object ShopField {
    const val NAME = "name"
    const val GREETING = "greeting"
    const val PHONE = "phone"
    const val ZALO = "zalo"
}

private val KEYS = mapOf("name" to ShopField.NAME, "greeting" to ShopField.GREETING, "phone_contact" to ShopField.PHONE, "zalo_contact" to ShopField.ZALO)
private val LIMITS = mapOf("name" to Limits(1, SHOP_NAME_MAX.toLong()), "greeting" to Limits(1, GREETING_MAX.toLong()), "zalo_contact" to Limits(ZALO_MIN.toLong(), ZALO_MAX.toLong()))

enum class ShopBanner { ERROR, OFFLINE }

data class ShopState(
    val stored: ShopInfo,
    val name: String = stored.name,
    val greeting: String = stored.greeting,
    val phone: String = stored.phoneContact,
    val zalo: String = stored.zaloContact,
    val problems: Map<String, Problem> = emptyMap(),
    val saving: Boolean = false,
    val banner: ShopBanner? = null,
    val discard: Boolean = false,
    val done: Boolean = false,
) {
    val changed: Boolean get() = name != stored.name || greeting != stored.greeting || phone != stored.phoneContact || zalo != stored.zaloContact
    val canSave: Boolean get() = changed && !saving
}

fun validateShop(state: ShopState): Map<String, Problem> = problemsOf(
    ShopField.NAME to Validation.text(state.name, SHOP_NAME_MAX),
    ShopField.GREETING to Validation.text(state.greeting, GREETING_MAX),
    ShopField.PHONE to Validation.phone(state.phone),
    ShopField.ZALO to (Validation.text(state.zalo, ZALO_MAX) ?: if (state.zalo.trim().length < ZALO_MIN) Problem.Range(ZALO_MIN.toLong(), ZALO_MAX.toLong()) else null),
)

sealed interface ShopIntent {
    data class Name(val value: String) : ShopIntent

    data class Greeting(val value: String) : ShopIntent

    data class Phone(val value: String) : ShopIntent

    data class Zalo(val value: String) : ShopIntent

    data object Save : ShopIntent

    data class Failed(val failure: OwnerFailure) : ShopIntent

    data object Saved : ShopIntent

    data object Back : ShopIntent

    data object Dismiss : ShopIntent
}

fun reduceShop(state: ShopState, intent: ShopIntent): ShopState = when (intent) {
    is ShopIntent.Name -> state.copy(name = intent.value.take(SHOP_NAME_MAX), problems = state.problems - ShopField.NAME, banner = null)
    is ShopIntent.Greeting -> state.copy(greeting = intent.value.take(GREETING_MAX), problems = state.problems - ShopField.GREETING, banner = null)
    is ShopIntent.Phone -> state.copy(phone = intent.value.take(PHONE_CHARS), problems = state.problems - ShopField.PHONE, banner = null)
    is ShopIntent.Zalo -> state.copy(zalo = intent.value.take(ZALO_MAX), problems = state.problems - ShopField.ZALO, banner = null)
    ShopIntent.Save -> if (!state.canSave) state else validateShop(state).let { if (it.isEmpty()) state.copy(saving = true, banner = null) else state.copy(problems = it) }
    ShopIntent.Saved -> state.copy(saving = false, done = true)
    is ShopIntent.Failed -> failed(state, intent.failure)
    ShopIntent.Back -> if (state.changed && !state.saving) state.copy(discard = true) else state
    ShopIntent.Dismiss -> state.copy(discard = false)
}

private fun failed(state: ShopState, failure: OwnerFailure): ShopState {
    val settled = state.copy(saving = false)
    return when {
        failure == OwnerFailure.Offline -> settled.copy(banner = ShopBanner.OFFLINE)
        failure is OwnerFailure.Fields -> settled.copy(problems = failure.problems(LIMITS).mapKeys { KEYS[it.key] ?: it.key })
        else -> settled.copy(banner = ShopBanner.ERROR)
    }
}

private const val PHONE_CHARS = 20
