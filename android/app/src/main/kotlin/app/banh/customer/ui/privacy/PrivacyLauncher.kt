package app.banh.customer.ui.privacy

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import app.banh.customer.BuildConfig
import app.banh.customer.R

/** The shop's privacy page: `GET <API base URL>/privacy` (api.md 4.5; UI document 5.7). */
object PrivacyLinks {
    const val PATH = "privacy"

    /** [apiBaseUrl] may or may not end with a slash; the result has exactly one between host part and path. */
    fun url(apiBaseUrl: String): String = apiBaseUrl.trimEnd('/') + "/" + PATH
}

/** Edge to the browser. Returns false when nothing could show the page. */
fun interface PrivacyLauncher {
    fun open(url: String): Boolean
}

/**
 * Plain `ACTION_VIEW`, not a Custom Tab: `androidx.browser` is not a dependency yet and a new one could not be checked
 * against a build. The page opens in the user's browser; the app and its form state stay behind it.
 */
class IntentPrivacyLauncher(private val context: Context) : PrivacyLauncher {
    override fun open(url: String): Boolean = try {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: ActivityNotFoundException) {
        false
    } catch (e: SecurityException) {
        false
    }
}

/** Test seam: what opens the page and how a failure is told. Null means the real browser and a `Toast`. */
class PrivacyEnvironment(val launcher: PrivacyLauncher, val notifyFailure: (String) -> Unit)

val LocalPrivacyEnvironment = compositionLocalOf<PrivacyEnvironment?> { null }

/** One handler for S-7 and S-8: opens the page, and on failure shows `ERR_OPEN_PRIVACY` (UI document 5.7). */
@Composable
fun rememberOpenPrivacy(): () -> Unit {
    val context = LocalContext.current
    val failureText = stringResource(R.string.err_open_privacy)
    val override = LocalPrivacyEnvironment.current
    return remember(context, failureText, override) {
        val launcher = override?.launcher ?: IntentPrivacyLauncher(context)
        val notify = override?.notifyFailure ?: { text -> Toast.makeText(context, text, Toast.LENGTH_LONG).show() }
        val action: () -> Unit = {
            if (!launcher.open(PrivacyLinks.url(BuildConfig.API_BASE_URL))) notify(failureText)
        }
        action
    }
}
