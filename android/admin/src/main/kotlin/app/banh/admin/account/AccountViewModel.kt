package app.banh.admin.account

import app.banh.admin.auth.SessionEndedException
import app.banh.admin.auth.SessionManager
import app.banh.core.common.MviViewModel
import app.banh.core.network.ApiException
import kotlinx.coroutines.CancellationException

enum class AccountDialog { NONE, SIGN_OUT, SIGN_OUT_OTHERS }

/** `Failed` is a toast (S-A13 Error); `Offline` is the offline text; both leave the phone signed in. */
enum class AccountMessage { NONE, OTHERS_DONE, FAILED, OFFLINE }

data class AccountState(val dialog: AccountDialog = AccountDialog.NONE, val busy: Boolean = false, val message: AccountMessage = AccountMessage.NONE)

sealed interface AccountIntent {
    data class Ask(val dialog: AccountDialog) : AccountIntent

    data object Dismiss : AccountIntent

    data object SignOutYes : AccountIntent

    data object SignOutOthersYes : AccountIntent

    data class Finished(val message: AccountMessage) : AccountIntent

    data object MessageShown : AccountIntent
}

fun reduceAccount(state: AccountState, intent: AccountIntent): AccountState = when (intent) {
    is AccountIntent.Ask -> if (state.busy) state else state.copy(dialog = intent.dialog, message = AccountMessage.NONE)
    AccountIntent.Dismiss -> state.copy(dialog = AccountDialog.NONE)
    AccountIntent.SignOutYes, AccountIntent.SignOutOthersYes -> if (state.busy) state else state.copy(dialog = AccountDialog.NONE, busy = true)
    is AccountIntent.Finished -> state.copy(busy = false, message = intent.message)
    AccountIntent.MessageShown -> state.copy(message = AccountMessage.NONE)
}

/** S-A13 (staff sheet) and the same two buttons on the owner's Settings placeholder (S-A6). */
class AccountViewModel(private val session: SessionManager) : MviViewModel<AccountState, AccountIntent, Nothing>(AccountState()) {
    override fun reduce(state: AccountState, intent: AccountIntent): AccountState = reduceAccount(state, intent)

    override suspend fun handle(intent: AccountIntent) {
        when (intent) {
            // Signing out clears the phone first, so it works offline too; the root then shows S-A1 (A_OFFLINE_SIGNOUT is its note).
            AccountIntent.SignOutYes -> session.signOut().also { dispatch(AccountIntent.Finished(AccountMessage.NONE)) }
            AccountIntent.SignOutOthersYes -> signOutOthers()
            else -> Unit
        }
    }

    private suspend fun signOutOthers() {
        val message = try {
            session.signOutOthers()
            AccountMessage.OTHERS_DONE
        } catch (e: CancellationException) {
            throw e
        } catch (_: SessionEndedException) {
            AccountMessage.NONE
        } catch (e: ApiException) {
            if (e.isOffline) AccountMessage.OFFLINE else AccountMessage.FAILED
        }
        dispatch(AccountIntent.Finished(message))
    }
}
