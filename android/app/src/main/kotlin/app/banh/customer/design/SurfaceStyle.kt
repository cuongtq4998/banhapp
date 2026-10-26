package app.banh.customer.design

import android.content.Context
import android.os.Build
import android.provider.Settings
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner

/** How cards and bars are drawn (ADR-0012). Layout, sizes and copy are identical in both. */
enum class SurfaceStyle {
    /** Translucent cards over natively blurred background blobs. */
    GLASS,

    /** `color.surface.solid` at 94% without blur (`material.fallback`). */
    OPAQUE,
}

/** `Modifier.blur` has an effect only from Android 12 (API 31), ADR-0012. */
private const val BLUR_MIN_SDK = Build.VERSION_CODES.S

fun surfaceStyleFor(sdkInt: Int, highContrast: Boolean): SurfaceStyle =
    if (sdkInt >= BLUR_MIN_SDK && !highContrast) SurfaceStyle.GLASS else SurfaceStyle.OPAQUE

/** System accessibility settings the design system reacts to. */
data class AccessibilityPreferences(val reduceMotion: Boolean, val highContrast: Boolean)

val LocalSurfaceStyle = compositionLocalOf { SurfaceStyle.OPAQUE }

/** True when animations are off; transitions then become short cross-fades (`motion.reduced`). */
val LocalReduceMotion = compositionLocalOf { false }

// Android has no public API for "reduce transparency"; the high-contrast text switch is the closest
// setting and is read by key. Unverified on devices.
private const val HIGH_TEXT_CONTRAST_SETTING = "high_text_contrast_enabled"

private fun readAccessibilityPreferences(context: Context): AccessibilityPreferences {
    val resolver = context.contentResolver
    val animatorScale = Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
    val highContrast = Settings.Secure.getInt(resolver, HIGH_TEXT_CONTRAST_SETTING, 0) == 1
    return AccessibilityPreferences(reduceMotion = animatorScale == 0f, highContrast = highContrast)
}

/** The settings are read again whenever the app returns to the foreground, where the customer may have changed them. */
@Composable
fun rememberAccessibilityPreferences(): AccessibilityPreferences {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var preferences by remember { mutableStateOf(readAccessibilityPreferences(context)) }
    DisposableEffect(lifecycleOwner, context) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_START) preferences = readAccessibilityPreferences(context)
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    return preferences
}
