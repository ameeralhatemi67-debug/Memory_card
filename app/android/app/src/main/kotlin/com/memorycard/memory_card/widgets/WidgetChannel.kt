package com.memorycard.memory_card.widgets

import android.app.Activity
import android.app.StatusBarManager
import android.content.ComponentName
import android.graphics.Bitmap
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Log
import android.util.SizeF
import com.memorycard.memory_card.R
import es.antonborri.home_widget.HomeWidgetPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.ByteArrayOutputStream

/**
 * What the Settings screen asks of the widgets: a picture of any widget drawn the way the home screen draws it
 * (so the Look settings can be seen as they change), and the Quick Settings tile.
 */
internal object WidgetChannel {
    const val NAME = "memorycard/widgets"

    fun register(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "preview" -> preview(activity, call, result)
                "addTile" -> addTile(activity, result)
                else -> result.notImplemented()
            }
        }
    }

    /** {cls, w, h, night, look} → PNG bytes of that widget at that size in dp, drawn from the live snapshot. */
    private fun preview(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        val cls = call.argument<String>("cls")
        val w = call.argument<Double>("w")?.toFloat()
        val h = call.argument<Double>("h")?.toFloat()
        val widget = cls?.let(Widgets::byClass)
        if (widget == null || w == null || h == null) return result.error("bad-args", "unknown widget or size", null)
        val night = call.argument<Boolean>("night") ?: false
        val look = call.argument<Map<String, Any?>>("look")
        Thread {
            try {
                var state = WidgetState.from(HomeWidgetPlugin.getData(activity))
                if (!state.ready) state = Samples.state()
                if (look != null) state = state.withLook(JSONObject(look))
                val bitmap = Preview.render(activity, widget, SizeF(w, h), night, state)
                val out = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                val bytes = out.toByteArray()
                activity.runOnUiThread { result.success(bytes) }
            } catch (e: Throwable) {
                Log.w(SceneWidget.TAG, "Could not draw a preview of $cls", e)
                activity.runOnUiThread { result.error("draw-failed", e.message, null) }
            }
        }.start()
    }

    /** Android 13 and later can ask "Add Memory Card to Quick Settings?" with a system dialog. */
    private fun addTile(activity: Activity, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return result.success("unsupported")
        try {
            val manager = activity.getSystemService(StatusBarManager::class.java)
            manager.requestAddTileService(
                ComponentName(activity, StudyTileService::class.java),
                "Memory Card",
                Icon.createWithResource(activity, R.drawable.wg_tile_icon),
                activity.mainExecutor,
            ) { code ->
                result.success(
                    when (code) {
                        StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED -> "added"
                        StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED -> "already"
                        else -> "declined"
                    },
                )
            }
        } catch (e: Throwable) {
            Log.w(SceneWidget.TAG, "Could not ask for the tile", e)
            result.success("unsupported")
        }
    }
}
