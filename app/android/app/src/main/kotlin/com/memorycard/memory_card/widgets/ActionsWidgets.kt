package com.memorycard.memory_card.widgets

import android.util.SizeF
import com.memorycard.memory_card.R
import kotlin.math.max
import kotlin.math.min

/** One quick action: where it goes and how it looks. */
private class Act(val label: String, val uri: String, val icon: Int, val fill: Int)

/**
 * Quick actions: one tap straight to Study (your last deck), the Daily mix, a new card or Search. 1 column is the
 * Study badge; 2 columns a card with Study and New card; 3 and 4 columns the shop's turning badges, each of its own
 * shape. The 2×2 is its own entry with four buttons. Everything goes straight where it says.
 */
abstract class ActionsBase : SceneWidget() {
    override val natural = Surface.PAPER

    private fun acts(st: WidgetState) = listOf(
        Act("Study", "memorycard://study", R.drawable.wg_ic_study, Hue.PAPER),
        Act("Daily mix", "memorycard://mix", R.drawable.wg_ic_mix, Hue.PEACH),
        Act("New card", "memorycard://new", R.drawable.wg_ic_new, Hue.GOOD),
        Act("Search", "memorycard://search", R.drawable.wg_ic_search, Hue.BLUE),
    )

    /** The badges sit straight on the wallpaper at 1 column and at 3 or more; the 2 column one is a card. */
    override fun surfaceFor(look: Look, size: SizeF): Surface =
        if (kind == "actions" && (size.width < 100f || size.width >= 215f)) Surface.CLEAR else look.surface(kind, natural)

    override fun draw(s: Scene, st: WidgetState, id: Int) {
        s.description = "Quick actions: Study, Daily mix, New card, Search."
        val all = acts(st)
        when {
            kind == "actionsgrid" -> grid(s, st, all)
            s.w < 100f -> single(s, st, all[0])
            s.w < 215f -> pair(s, all)
            else -> badges(s, all.take(if (s.w < 290f) 3 else 4))
        }
    }

    /** A label on a light chip with dark lettering, so it reads on any wallpaper. */
    private fun chip(s: Scene, text: String, cx: Float, base: Float, maxW: Float) {
        val tw = min(maxW, s.measure(text, 11.5f, s.uiBold)) + 14f
        s.pill(s.col(0xE0F1F1F1.toInt()), cx - tw / 2f, base - 12.5f, tw, 17f)
        s.text(s.col(Hue.GRAPHITE), text, cx, base, 11.5f, s.uiBold, Align.CENTER, maxW = tw - 12f)
    }

    /** 1×1: the Study badge, ink, with the logo. */
    private fun single(s: Scene, st: WidgetState, a: Act) {
        val size = min(s.w - 8f, min(58f, s.h - 34f))
        val cx = s.w / 2f
        val cy = max(size / 2f + 4f, (s.h - 22f) / 2f)
        s.sprite(Fx.BADGE, cx - size / 2f, cy - size / 2f, size, size, s.faceTones().second.first, s.faceTones().second.second) {
            s.badge(s.ink(), 0, cx, cy, size)
        }
        s.vec(s.onInk(), R.drawable.wg_logo, cx - 9f, cy - 11.5f, 18f, 23f)
        chip(s, a.label, cx, s.h - 8f, s.w - 6f)
        s.hit(0f, 0f, s.w, s.h, SceneWidget.open(s.ctx, a.uri), a.label, 26f)
    }

    /** 2×1: a card with Study over New card. */
    private fun pair(s: Scene, all: List<Act>) {
        val pad = 12f
        val bh = min(38f, (s.h - pad * 2 - 6f) / 2f)
        val iw = s.w - pad * 2
        val y0 = (s.h - bh * 2 - 6f) / 2f
        val study = all[0]
        s.pill(s.ink(), pad, y0, iw, bh)
        s.vec(s.onInk(), R.drawable.wg_logo, s.w / 2f - 38f, y0 + bh / 2f - 7.5f, 12f, 15f)
        s.text(s.onInk(), "Study", s.w / 2f - 20f, y0 + bh / 2f, 18f, s.display, middle = true)
        s.hit(pad, y0, iw, bh, SceneWidget.open(s.ctx, study.uri), "Study", bh / 2f)
        val create = all[2]
        val y1 = y0 + bh + 6f
        s.pill(s.ink(Shade.SOFT), pad, y1, iw, bh)
        s.vec(s.ink(), R.drawable.wg_ic_new, s.w / 2f - 46f, y1 + bh / 2f - 6.5f, 13f, 13f)
        s.text(s.ink(), "New card", s.w / 2f - 29f, y1 + bh / 2f, 18f, s.display, middle = true)
        s.hit(pad, y1, iw, bh, SceneWidget.open(s.ctx, create.uri), "New card", bh / 2f)
    }

    /** 3 to 4 columns: the shop's badges in a row, each turning, each of its own shape and colour. */
    private fun badges(s: Scene, shown: List<Act>) {
        val size = min(56f, s.h - 36f)
        val n = shown.size
        val cell = s.w / n
        for ((i, a) in shown.withIndex()) {
            val cx = cell * i + cell / 2f
            val cy = 8f + size / 2f
            s.sprite(Fx.BADGE, cx - size / 2f, cy - size / 2f, size, size, a.fill, a.fill) { s.badge(s.col(a.fill), i, cx, cy, size) }
            s.vec(s.col(Hue.GRAPHITE), a.icon, cx - 11f, cy - 11f, 22f, 22f)
            chip(s, a.label, cx, s.h - 8f, cell - 8f)
            s.hit(cell * i + 2f, 0f, cell - 4f, s.h, SceneWidget.open(s.ctx, a.uri), a.label, 22f)
        }
    }

    /** 2×2: four buttons, Study in ink. */
    private fun grid(s: Scene, st: WidgetState, all: List<Act>) {
        val pad = 12f
        val gap = 8f
        val tw = (s.w - pad * 2 - gap) / 2f
        val th = (s.h - pad * 2 - gap) / 2f
        val r = s.look.inner(16f)
        for ((i, a) in all.withIndex()) {
            val x = pad + (i % 2) * (tw + gap)
            val y = pad + (i / 2) * (th + gap)
            val study = i == 0
            s.rect(if (study) s.ink() else s.ink(Shade.SOFT), x, y, tw, th, r)
            val main = if (study) s.onInk() else s.ink()
            val sub = when (i) {
                0 -> if (st.goalHit) "goal met" else "${st.left} to go"
                1 -> if (st.mixSlipping > 0) "${st.mixSlipping} slipping" else ""
                else -> ""
            }
            val iconY = y + th / 2f - 18f - (if (sub.isEmpty()) 0f else 4f)
            s.vec(main, a.icon, x + tw / 2f - 10f, iconY, 20f, 20f)
            s.text(main, a.label, x + tw / 2f, iconY + 36f, 12.5f, s.uiBold, Align.CENTER, maxW = tw - 8f)
            if (sub.isNotEmpty()) s.text(if (study) s.onInk(0.7f) else s.ink(Shade.MUTED), sub, x + tw / 2f, iconY + 50f, 10.5f, s.uiBold, Align.CENTER, maxW = tw - 8f)
            s.hit(x, y, tw, th, SceneWidget.open(s.ctx, a.uri), a.label, r)
        }
    }
}

/** Quick actions: Study, Daily mix, New card and Search in a row of 1 to 4 columns. */
class ActionsWidget : ActionsBase() {
    override val kind = "actions"
    override val cells = listOf(4 to 1, 1 to 1, 2 to 1, 3 to 1)
}

/** Quick actions, grid: four buttons in 2×2. */
class ActionsGridWidget : ActionsBase() {
    override val kind = "actionsgrid"
    override val cells = listOf(2 to 2)
}
