package app.banh.customer.ui.contact

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri

/** Edge to the Zalo app and the dialer. Both return false when the system cannot open the link. */
interface ContactLauncher {
    fun openZalo(zaloContact: String): Boolean

    fun openPhone(phoneContact: String): Boolean
}

class IntentContactLauncher(private val context: Context) : ContactLauncher {
    override fun openZalo(zaloContact: String): Boolean =
        start(Intent.ACTION_VIEW, ContactLinks.zaloUrl(zaloContact))

    // ACTION_DIAL only opens the dialer with the number filled in, so no permission is needed.
    override fun openPhone(phoneContact: String): Boolean =
        start(Intent.ACTION_DIAL, ContactLinks.phoneUri(phoneContact))

    // No resolveActivity pre-check (ADR-0015): it would need package visibility declarations.
    private fun start(action: String, uri: String): Boolean = try {
        context.startActivity(Intent(action, Uri.parse(uri)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: ActivityNotFoundException) {
        false
    }
}
