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
            StreakTallWidget(),
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
        "SealWidget", "StreakWidget", "StreakTallWidget", "TodayWidget", "QuickCardWidget",
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

    /**
     * Writes a PNG of each widget at each of its sizes, light and dark, plus a few other days, into [dir] (development).
     * [look] is laid over every day's own look (an accent, a theme). With [pieces], each picture is drawn without its
     * moving pieces and a .json beside it says where they go and in which colours (to animate them elsewhere).
     */
    fun dump(ctx: Context, dir: File, only: Set<String>? = null, look: JSONObject? = null, pieces: Boolean = false) {
        dir.mkdirs()
        dir.listFiles()?.forEach { it.delete() }
        fun lookWith(key: String? = null, value: String? = null): JSONObject? {
            if (look == null && key == null) return null
            val j = JSONObject(look?.toString() ?: "{}")
            if (key != null) j.put(key, value)
            return j
        }
        val days = listOf(
            "a" to Samples.state(look = lookWith()),
            "b" to Samples.state(done = 20, look = lookWith()),
            "c" to Samples.state(done = 0, streak = 0, empty = true, look = lookWith()),
            "d" to Samples.state(turned = true, look = lookWith()),
            "e" to Samples.state(look = lookWith("quick", "side")),
            "f" to Samples.state(turned = true, look = lookWith("quick", "side")),
            "g" to Samples.state(memberBack = true, look = lookWith()),
            "h" to Samples.state(answered = listOf("c1"), look = lookWith()),
            "z" to Samples.blank(),
        )
        for (w in Widgets.all) {
            if (only != null && Widgets.nameOf(w) !in only) continue
            for ((label, size) in w.previews + w.altPreviews) {
                for ((tag, st) in days) {
                    for (night in listOf(false, true)) {
                        val name = "${Widgets.nameOf(w)}_${label.ifEmpty { "x" }}_$tag${if (night) "_night" else ""}"
                        val scene = w.scene(ctx, st, size, animated = pieces)
                        save(scene.flatten(night), File(dir, "$name.png"))
                        if (pieces) {
                            save(scene.flatten(night, withFace = false), File(dir, "${name}_ink.png"))
                            File(dir, "$name.json").writeText(piecesOf(scene, night).toString())
                        }
                    }
                }
            }
        }
    }

    /** The face (colour, corner radius in dp; none for a bare widget) and where the moving pieces of [scene] go (dp), in that theme. */
    private fun piecesOf(scene: Scene, night: Boolean): JSONObject {
        val (face, _, _) = scene.faceColors(if (night) scene.look.night else scene.look.day)
        val faceJson = if (scene.surface == Surface.CLEAR) JSONObject.NULL else JSONObject()
            .put("color", String.format("#%08X", (face and 0x00FFFFFF) or ((scene.look.opacity * 255 / 100) shl 24)))
            .put("radius", (if (scene.pill) 999f else scene.look.radius).toDouble())
        val list = org.json.JSONArray()
        for (sp in scene.sprites) {
            list.put(
                JSONObject().put("fx", sp.fx.name).put("x", sp.x.toDouble()).put("y", sp.y.toDouble())
                    .put("w", sp.w.toDouble()).put("h", sp.h.toDouble())
                    .put("color", String.format("#%08X", if (night) sp.night else sp.day)),
            )
        }
        return JSONObject().put("w", scene.w.toDouble()).put("h", scene.h.toDouble()).put("face", faceJson).put("pieces", list)
    }

    private fun save(bitmap: Bitmap, file: File) {
        FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
}
