package app.banh.admin.push

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import app.banh.admin.MainActivity
import app.banh.admin.R

const val CHANNEL_ID = "new_orders"
const val EXTRA_ORDER_CODE = "order_code"

/** The channel `A_NOTIF_CHANNEL` (Android 8 and later; default importance) and the notification for a message the system did not draw. */
class OrderNotifier(private val context: Context) : PushNotifier {
    fun ensureChannel() {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(CHANNEL_ID, context.getString(R.string.a_notif_channel), NotificationManager.IMPORTANCE_DEFAULT))
    }

    override fun show(message: PushMessage) {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return
        val open = Intent(context, MainActivity::class.java).putExtra(EXTRA_ORDER_CODE, message.orderCode).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val tap = PendingIntent.getActivity(context, message.orderCode.hashCode(), open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        // No name, phone, address or note ever: code, cake count and date only (FR-26).
        val body = context.getString(R.string.a_notif_body, message.orderCode, message.cakes.orEmpty(), message.date.orEmpty())
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_list)
            .setContentTitle(context.getString(R.string.a_notif_title))
            .setContentText(body)
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        context.getSystemService(NotificationManager::class.java).notify(message.orderCode.hashCode(), notification)
    }
}
