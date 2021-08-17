package deckers.thibault.aves.channel.calls

import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import deckers.thibault.aves.MainActivity
import deckers.thibault.aves.R
import deckers.thibault.aves.channel.calls.Coresult.Companion.safe
import deckers.thibault.aves.utils.BitmapUtils.centerSquareCrop
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import java.util.*

class AppShortcutHandler(private val context: Context) : MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canPin" -> safe(call, result, ::canPin)
            "pin" -> GlobalScope.launch(Dispatchers.IO) { safe(call, result, ::pin) }
            else -> result.notImplemented()
        }
    }

    private fun isSupported() = ShortcutManagerCompat.isRequestPinShortcutSupported(context)

    private fun canPin(@Suppress("UNUSED_PARAMETER") call: MethodCall, result: MethodChannel.Result) {
        result.success(isSupported())
    }

    private fun pin(call: MethodCall, result: MethodChannel.Result) {
        val label = call.argument<String>("label")
        val iconBytes = call.argument<ByteArray>("iconBytes")
        val filters = call.argument<List<String>>("filters")
        if (label == null || filters == null) {
            result.error("pin-args", "failed because of missing arguments", null)
            return
        }

        if (!isSupported()) {
            result.error("pin-unsupported", "failed because the launcher does not support pinning shortcuts", null)
            return
        }

        var icon: IconCompat? = null
        if (iconBytes?.isNotEmpty() == true) {
            var bitmap = BitmapFactory.decodeByteArray(iconBytes, 0, iconBytes.size)
            bitmap = centerSquareCrop(context, bitmap, 256)
            if (bitmap != null) {
                // adaptive, so the bitmap is used as background and covers the whole icon
                icon = IconCompat.createWithAdaptiveBitmap(bitmap)
            }
        }
        if (icon == null) {
            // shortcut adaptive icons are placed in `mipmap`, not `drawable`,
            // so that foreground is rendered at the intended scale
            val supportAdaptiveIcon = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O

            icon = IconCompat.createWithResource(context, if (supportAdaptiveIcon) R.mipmap.ic_shortcut_collection else R.drawable.ic_shortcut_collection)
        }

        val intent = Intent(Intent.ACTION_MAIN, null, context, MainActivity::class.java)
            .putExtra("page", "/collection")
            .putExtra("filters", filters.toTypedArray())
            // on API 25, `String[]` or `ArrayList` extras are null when using the shortcut
            // so we use a joined `String` as fallback
            .putExtra("filtersString", filters.joinToString(MainActivity.EXTRA_STRING_ARRAY_SEPARATOR))

        // multiple shortcuts sharing the same ID cannot be created with different labels or icons
        // so we provide a unique ID for each one, and let the user manage duplicates (i.e. same filter set), if any
        val shortcut = ShortcutInfoCompat.Builder(context, UUID.randomUUID().toString())
            .setShortLabel(label)
            .setIcon(icon)
            .setIntent(intent)
            .build()
        ShortcutManagerCompat.requestPinShortcut(context, shortcut, null)

        result.success(true)
    }

    companion object {
        const val CHANNEL = "deckers.thibault/aves/shortcut"
    }
}