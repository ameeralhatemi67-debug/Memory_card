package com.memorycard.memory_card.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.SizeF
import android.widget.RemoteViews
import com.memorycard.memory_card.MainActivity
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * A Memory Card widget, drawn at a few sizes. Android 12+ gets every size at once and shows the largest that
 * fits as the widget is resized; older launchers report the size and get the one layout that fits.
 */
abstract class McWidget : HomeWidgetProvider() {
    /** The smallest space (dp) each layout needs, smallest first. */
    internal abstract val sizes: List<SizeF>

    internal abstract fun build(ctx: Context, size: Int, state: WidgetState, widgetId: Int): RemoteViews

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val state = WidgetState(widgetData)
        for (id in appWidgetIds) {
            try {
                appWidgetManager.updateAppWidget(id, views(context, appWidgetManager, id, state))
            } catch (e: Exception) {
                Log.w("MemoryCardWidgets", "Could not draw widget $id", e)
            }
        }
    }

    /** After the app is updated, Android shows the placeholder layout again: redraw straight away. */
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val manager = AppWidgetManager.getInstance(context)
            onUpdate(context, manager, manager.getAppWidgetIds(ComponentName(context, javaClass)))
            return
        }
        super.onReceive(context, intent)
    }

    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), HomeWidgetPlugin.getData(context))
        }
    }

    private fun views(ctx: Context, manager: AppWidgetManager, id: Int, state: WidgetState): RemoteViews {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return RemoteViews(sizes.indices.associate { sizes[it] to build(ctx, it, state, id) })
        }
        val o = manager.getAppWidgetOptions(id)
        val w = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val h = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        val fit = sizes.indices.lastOrNull { sizes[it].width <= w && sizes[it].height <= h } ?: 0
        return build(ctx, fit, state, id)
    }

    internal companion object {
        /** Opens the app at [uri]; lib/app.dart › _fromWidget decides the screen. */
        fun open(ctx: Context, uri: String): PendingIntent =
            HomeWidgetLaunchIntent.getActivity(ctx, MainActivity::class.java, Uri.parse(uri))

        /** Redraws every placed widget of [cls]. */
        fun refresh(ctx: Context, cls: Class<out McWidget>) {
            val ids = AppWidgetManager.getInstance(ctx).getAppWidgetIds(ComponentName(ctx, cls))
            if (ids.isEmpty()) return
            ctx.sendBroadcast(
                Intent(ctx, cls).setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE).putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
            )
        }
    }
}
