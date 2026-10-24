package com.memorycard.memory_card

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import com.memorycard.memory_card.widgets.Preview
import com.memorycard.memory_card.widgets.Widgets
import org.json.JSONObject
import java.io.File

/**
 * Development only (the debug manifest registers it): drive the widgets over adb.
 *   adb shell am broadcast -n com.memorycard.app/com.memorycard.memory_card.DebugReceiver -a com.memorycard.debug.PIN --es cls SealWidget
 *   adb shell am broadcast -n com.memorycard.app/com.memorycard.memory_card.DebugReceiver -a com.memorycard.debug.DUMP [--es only SealWidget,ForecastWidget]
 *       [--es look '{"accent":"blue"}'] [--ez pieces true] [--es sub blue]
 * The dump lands in /sdcard/Android/data/com.memorycard.app/files/widget_dump (or widget_dump/<sub>). `look` is laid
 * over every sample day; `pieces` leaves the moving pieces out of the pictures and writes where they go beside them.
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
                val sub = intent.getStringExtra("sub")
                val dir = File(ctx.getExternalFilesDir(null), if (sub == null) "widget_dump" else "widget_dump/$sub")
                val only = intent.getStringExtra("only")?.split(',')?.toSet()
                val look = intent.getStringExtra("look")?.let { JSONObject(it) }
                val pieces = intent.getBooleanExtra("pieces", false)
                // Off the main thread: a full dump takes longer than a broadcast may.
                val pending = goAsync()
                Thread {
                    try {
                        Preview.dump(ctx, dir, only, look, pieces)
                        Log.i("McDebug", "dumped ${dir.listFiles()?.size} pictures to $dir")
                    } catch (e: Throwable) {
                        Log.e("McDebug", "dump failed", e)
                    } finally {
                        pending.finish()
                    }
                }.start()
            }
        }
    }
}
