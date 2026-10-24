package com.memorycard.memory_card.widgets

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import com.memorycard.memory_card.MainActivity
import com.memorycard.memory_card.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * A Memory Card widget. It draws itself (see [Scene]) at the size the launcher says it has, so it can show whatever
 * the design asks for at any size, and the launcher only composes layers and runs the moving pieces.
 * A widget is one drawing function; several providers (the entries of the widget picker) may share it.
 */
abstract class SceneWidget : HomeWidgetProvider() {
    /** The name used by the user's Look settings and the snapshot ("seal", "streak"…). */
    internal abstract val kind: String

    /** The face it was designed with; the user may swap paper for ink. */
    internal abstract val natural: Surface

    /** A change turns the card over (Quick card, membership card) instead of dissolving. */
    internal open val turns: Boolean get() = false

    /** The sizes it comes in as (columns, rows), the default first: for previews, the picker and the dump. */
    internal abstract val cells: List<Pair<Int, Int>>

    /** The size (dp) drawn until the launcher says what the size is: the default size on a typical phone. */
    internal val fallback: SizeF get() = Grid.A.size(cells.first().first, cells.first().second)

    /** Each size as a label and dp, on the Pixel-style grid (taller rows) and on a Samsung-style one. */
    internal val previews: List<Pair<String, SizeF>> get() = cells.map { (c, r) -> "$c×$r" to Grid.A.size(c, r) }
    internal val altPreviews: List<Pair<String, SizeF>> get() = cells.map { (c, r) -> "$c×$r·b" to Grid.B.size(c, r) }

    /** The face at [size]: the user's pick, else the natural one. A widget may go bare at some sizes (badges on the wallpaper). */
    internal open fun surfaceFor(look: Look, size: SizeF): Surface = look.surface(kind, natural)

    /** Draws the widget into [s]. [id] is the widget's id (0 for a preview). */
    internal abstract fun draw(s: Scene, st: WidgetState, id: Int)

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val state = WidgetState.from(widgetData)
        for (id in appWidgetIds) {
            try {
                appWidgetManager.updateAppWidget(id, views(context, appWidgetManager, id, state))
            } catch (e: Exception) {
                Log.w(TAG, "Could not draw widget $id", e)
            }
        }
    }

    /** After the app is updated, Android shows the placeholder layout again: redraw straight away. */
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val manager = AppWidgetManager.getInstance(context)
            onUpdate(context, manager, manager.getAppWidgetIds(ComponentName(context, javaClass)), HomeWidgetPlugin.getData(context))
            return
        }
        super.onReceive(context, intent)
    }

    /** The widget was resized: draw it again at its new size. */
    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), HomeWidgetPlugin.getData(context))
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val pages = context.getSharedPreferences(PAGES, Context.MODE_PRIVATE).edit()
        for (id in appWidgetIds) pages.remove("$id")
        pages.apply()
        super.onDeleted(context, appWidgetIds)
    }

    /** The widget drawn at [size] dp. Previews and tests call this too, with [animated] off and [id] 0. */
    internal fun scene(ctx: Context, st: WidgetState, size: SizeF, animated: Boolean, id: Int = 0): Scene {
        val s = Scene(ctx, size.width, size.height, st.look, surfaceFor(st.look, size), animated)
        s.anywhere = open(ctx, "memorycard://study")
        draw(s, st, id)
        return s
    }

    private fun views(ctx: Context, manager: AppWidgetManager, id: Int, st: WidgetState): RemoteViews {
        val o = manager.getAppWidgetOptions(id)
        // Portrait: the narrowest the widget gets across, the tallest it gets down.
        val w = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val h = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        val size = if (w > 0 && h > 0) SizeF(w.toFloat(), h.toFloat()) else fallback
        Log.d(TAG, "${javaClass.simpleName} $id is ${size.width.toInt()}×${size.height.toInt()} dp")
        val scene = scene(ctx, st, size, animated = st.look.motion && Scene.canAnimate, id = id)
        return SceneViews.build(ctx, scene, id, turns)
    }

    internal companion object {
        const val TAG = "MemoryCardWidgets"
        const val PAGES = "mc.widget.pages"

        /** Opens the app at [uri]; lib/app.dart › _fromWidget decides the screen. */
        fun open(ctx: Context, uri: String): PendingIntent =
            HomeWidgetLaunchIntent.getActivity(ctx, MainActivity::class.java, Uri.parse(uri))

        /** Redraws every placed widget of [cls]. */
        fun refresh(ctx: Context, cls: Class<out SceneWidget>) {
            val ids = AppWidgetManager.getInstance(ctx).getAppWidgetIds(ComponentName(ctx, cls))
            if (ids.isEmpty()) return
            ctx.sendBroadcast(
                Intent(ctx, cls).setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE).putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
            )
        }
    }
}

/**
 * What a widget of [c] columns and [r] rows measures on two common launcher grids (dp, on a phone about 411 dp wide):
 * A is what the Pixel launcher gives (measured on the emulator); B is a Samsung-style grid with shorter rows.
 */
internal class Grid(private val w: Float, private val gapW: Float, private val h: Float, private val gapH: Float) {
    fun size(c: Int, r: Int) = SizeF(w * c - gapW, h * r - gapH)

    companion object {
        val A = Grid(94f, 16f, 125f, 17f)
        val B = Grid(95f, 24f, 112f, 23f)
    }
}

/** Composes a [Scene] into the RemoteViews the launcher shows. */
internal object SceneViews {
    @SuppressLint("NewApi")
    fun build(ctx: Context, scene: Scene, id: Int, turns: Boolean): RemoteViews {
        val layout = when {
            !scene.look.motion -> R.layout.wg_scene_still
            turns -> R.layout.wg_scene_turn
            else -> R.layout.wg_scene_fade
        }
        val v = RemoteViews(ctx.packageName, layout)
        val look = scene.look
        val modern = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        val nightNow = (ctx.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

        // The face: a white shape tinted with the paper (or ink) of the day's and the night's theme, as solid as the user likes.
        val (dayFace, dayMain, dayOver) = scene.faceColors(look.day)
        val (nightFace, nightMain, nightOver) = scene.faceColors(look.night)
        if (scene.surface == Surface.CLEAR) {
            v.setViewVisibility(R.id.bg, View.GONE)
        } else {
            val alpha = look.opacity * 255 / 100
            v.setImageViewResource(R.id.bg, look.faceRes(scene.pill))
            val dayTint = (dayFace and 0x00FFFFFF) or (alpha shl 24)
            val nightTint = (nightFace and 0x00FFFFFF) or (alpha shl 24)
            if (modern) {
                v.setColorStateList(R.id.bg, "setImageTintList", ColorStateList.valueOf(dayTint), ColorStateList.valueOf(nightTint))
            } else {
                v.setInt(R.id.bg, "setColorFilter", if (nightNow) nightTint else dayTint)
            }
        }

        // The drawing goes on the page that is not showing, so a change turns or dissolves into the new one.
        val pages = ctx.getSharedPreferences(SceneWidget.PAGES, Context.MODE_PRIVATE)
        val fp = scene.fingerprint()
        val saved = if (id == 0) null else pages.getString("$id", null)
        val savedPage = saved?.substringBefore(':')?.toIntOrNull() ?: 0
        val page = when {
            saved == null -> 0
            saved.substringAfter(':', "") == fp -> savedPage
            else -> 1 - savedPage
        }
        if (id != 0 && saved != "$page:$fp") pages.edit().putString("$id", "$page:$fp").apply()

        val fgId = if (page == 0) R.id.p0_fg else R.id.p1_fg
        val onId = if (page == 0) R.id.p0_on else R.id.p1_on
        val artId = if (page == 0) R.id.p0_art else R.id.p1_art
        // Only the layers that were drawn on travel to the launcher (a bitmap is memory there until it is replaced).
        for ((i, layer) in listOf(fgId to scene.fg, onId to scene.on, artId to scene.art).withIndex()) {
            if (scene.used[i]) {
                v.setImageViewBitmap(layer.first, layer.second)
                v.setViewVisibility(layer.first, View.VISIBLE)
            } else {
                v.setViewVisibility(layer.first, View.GONE)
            }
        }
        if (modern) {
            v.setColorInt(fgId, "setColorFilter", dayMain, nightMain)
            v.setColorInt(onId, "setColorFilter", dayOver, nightOver)
        } else {
            v.setInt(fgId, "setColorFilter", if (nightNow) nightMain else dayMain)
            v.setInt(onId, "setColorFilter", if (nightNow) nightOver else dayOver)
        }
        v.setDisplayedChild(R.id.pages, page)
        v.setContentDescription(R.id.root, scene.description)

        // Moving pieces and tap targets are placed in dp over the drawing (Android 12 and later).
        val used = HashMap<Fx, Int>()
        for (sp in scene.sprites) {
            val slot = sp.fx.ids[used.merge(sp.fx, 1, Int::plus)!! - 1]
            place(v, slot, sp.x, sp.y, sp.w, sp.h)
            v.setViewVisibility(slot, View.VISIBLE)
            v.setColorStateList(slot, "setIndeterminateTintList", ColorStateList.valueOf(sp.day), ColorStateList.valueOf(sp.night))
        }

        v.setInt(R.id.hit_all, "setBackgroundResource", look.rippleRes(scene.pill))
        (scene.anywhere ?: scene.hits.firstOrNull()?.pi)?.let { v.setOnClickPendingIntent(R.id.hit_all, it) }
        if (modern) {
            val slots = intArrayOf(R.id.hit0, R.id.hit1, R.id.hit2, R.id.hit3, R.id.hit4, R.id.hit5, R.id.hit6, R.id.hit7)
            for ((i, t) in scene.hits.withIndex()) {
                val slot = slots[i]
                place(v, slot, t.x, t.y, t.w, t.h)
                v.setInt(slot, "setBackgroundResource", rippleFor(t.radius, look))
                v.setViewVisibility(slot, View.VISIBLE)
                v.setOnClickPendingIntent(slot, t.pi)
                if (t.label.isNotEmpty()) v.setContentDescription(slot, t.label)
            }
        }
        return v
    }

    @SuppressLint("NewApi")
    private fun place(v: RemoteViews, slot: Int, x: Float, y: Float, w: Float, h: Float) {
        val dp = TypedValue.COMPLEX_UNIT_DIP
        v.setViewLayoutWidth(slot, w, dp)
        v.setViewLayoutHeight(slot, h, dp)
        v.setViewLayoutMargin(slot, RemoteViews.MARGIN_LEFT, x, dp)
        v.setViewLayoutMargin(slot, RemoteViews.MARGIN_TOP, y, dp)
    }

    private fun rippleFor(radius: Float, look: Look): Int = when {
        look.corners == "square" -> R.drawable.wg_ripple_6
        radius >= 24f -> R.drawable.wg_ripple_pill
        radius >= 18f -> R.drawable.wg_ripple_22
        radius >= 10f -> R.drawable.wg_ripple_14
        else -> R.drawable.wg_ripple_6
    }
}
