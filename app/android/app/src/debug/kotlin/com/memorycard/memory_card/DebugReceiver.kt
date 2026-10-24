package com.memorycard.memory_card

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import com.memorycard.memory_card.widgets.Preview
import com.memorycard.memory_card.widgets.Widgets
import java.io.File

/**
 * Development only (the debug manifest registers it): drive the widgets over adb.
 *   adb shell am broadcast -n com.memorycard.app/com.memorycard.memory_card.DebugReceiver -a com.memorycard.debug.PIN --es cls SealWidget
 *   adb shell am broadcast -n com.memorycard.app/com.memorycard.memory_card.DebugReceiver -a com.memorycard.debug.DUMP
 * The dump lands in /sdcard/Android/data/com.memorycard.app/files/widget_dump.
 */
class DebugReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        when (intent.action) {
            "com.memorycard.debug.PIN" -> {
                val cls = intent.getStringExtra("cls") ?: return
                val manager = AppWidgetManager.getInstance(ctx)
                val ok = manager.isRequestPinAppWidgetSupported &&
                    manager.requestPinAppWidget(ComponentName(ctx, "com.memorycard.memory_card.widgets.$cls"), null, null)
                Log.i("McDebug", "pin $cls -> $ok")
            }
            "com.memorycard.debug.REFRESH" -> Widgets.refreshAll(ctx)
            "com.memorycard.debug.INFO" -> {
                val manager = AppWidgetManager.getInstance(ctx)
                for (i in manager.getInstalledProvidersForPackage(ctx.packageName, null)) {
                    Log.i(
                        "McDebug",
                        "${i.provider.shortClassName.substringAfterLast('.')}: min ${i.minWidth}x${i.minHeight} " +
                            "resizeMin ${i.minResizeWidth}x${i.minResizeHeight} resizeMax ${i.maxResizeWidth}x${i.maxResizeHeight} " +
                            "cells ${i.targetCellWidth}x${i.targetCellHeight} mode ${i.resizeMode}",
                    )
                }
            }
            "com.memorycard.debug.DUMP" -> {
                val dir = File(ctx.getExternalFilesDir(null), "widget_dump")
                try {
                    Preview.dump(ctx, dir)
                    Log.i("McDebug", "dumped ${dir.listFiles()?.size} pictures to $dir")
                } catch (e: Throwable) {
                    Log.e("McDebug", "dump failed", e)
                }
            }
        }
    }
}
