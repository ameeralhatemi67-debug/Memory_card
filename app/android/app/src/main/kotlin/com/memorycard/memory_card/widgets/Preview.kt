package com.memorycard.memory_card.widgets

import android.content.Context
import android.graphics.Bitmap
import android.util.SizeF
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

/** Every widget provider, in the order the app lists them. */
internal object Widgets {
    val all: List<SceneWidget> by lazy {
        listOf(
            SealWidget(),
            StreakWidget(),
            TodayWidget(),
            QuickCardWidget(),
            ActionsWidget(),
            ActionsGridWidget(),
            ActivityWidget(),
            ForecastWidget(),
            MembershipWidget(),
            CardOfDayWidget(),
            SealsWidget(),
            DecksWidget(),
        )
    }

    /** The provider class names, in the order of [all] (kept as text: a release build may rename the classes). */
    private val names = listOf(
        "SealWidget", "StreakWidget", "TodayWidget", "QuickCardWidget",
        "ActionsWidget", "ActionsGridWidget", "ActivityWidget", "ForecastWidget", "MembershipWidget",
        "CardOfDayWidget", "SealsWidget", "DecksWidget",
    )

    fun byClass(name: String): SceneWidget? = names.indexOf(name).takeIf { it >= 0 }?.let { all[it] }

    fun nameOf(widget: SceneWidget): String = names.getOrElse(all.indexOf(widget)) { widget.javaClass.simpleName }

    /** Asks every placed widget (but [except]) to draw again: an answer on the Quick card moves most of them. */
    fun refreshAll(ctx: Context, except: Class<*>? = null) {
        for (w in all) if (w.javaClass != except) SceneWidget.refresh(ctx, w.javaClass)
    }
}

/** Drawing widgets as pictures: the picker's previews, the settings screen, and development dumps. */
internal object Preview {
    /** [widget] at [size] dp as one picture, by day or by night, drawn from [st] (a made-up day by default). */
    fun render(ctx: Context, widget: SceneWidget, size: SizeF, night: Boolean, st: WidgetState = Samples.state()): Bitmap =
        widget.scene(ctx, st, size, animated = false).flatten(night)

    /** Writes a PNG of each widget at each of its sizes, light and dark, plus a few other days, into [dir] (development). */
    fun dump(ctx: Context, dir: File, only: Set<String>? = null) {
        dir.mkdirs()
        dir.listFiles()?.forEach { it.delete() }
        val days = listOf(
            "a" to Samples.state(),
            "b" to Samples.state(done = 20),
            "c" to Samples.state(done = 0, streak = 0, empty = true),
            "d" to Samples.state(turned = true),
            "e" to Samples.state(look = JSONObject().put("quick", "side")),
            "f" to Samples.state(turned = true, look = JSONObject().put("quick", "side")),
            "g" to Samples.state(memberBack = true),
            "z" to Samples.blank(),
        )
        for (w in Widgets.all) {
            if (only != null && Widgets.nameOf(w) !in only) continue
            for ((label, size) in w.previews + w.altPreviews) {
                for ((tag, st) in days) {
                    for (night in listOf(false, true)) {
                        val name = "${Widgets.nameOf(w)}_${label.ifEmpty { "x" }}_$tag${if (night) "_night" else ""}.png"
                        save(render(ctx, w, size, night, st), File(dir, name))
                    }
                }
            }
        }
    }

    private fun save(bitmap: Bitmap, file: File) {
        FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
}
