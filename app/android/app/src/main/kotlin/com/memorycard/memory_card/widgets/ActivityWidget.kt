package com.memorycard.memory_card.widgets

import android.util.SizeF
import java.text.NumberFormat
import java.util.Locale
import kotlin.math.floor
import kotlin.math.min
import kotlin.math.roundToInt

/** 1,284: a whole number with its thousands marked. */
internal fun grouped(n: Int): String = NumberFormat.getIntegerInstance(Locale.US).format(n)

/** How much a day's swipes light its cell: none, a few, some, a lot, a great many (the profile card's levels). */
internal fun heatLevel(swipes: Int): Int = when {
    swipes <= 0 -> 0
    swipes < 10 -> 1
    swipes < 25 -> 2
    swipes < 45 -> 3
    else -> 4
}

/** The ink strength of each level; a quiet day is still a faint square, so the grid reads as a calendar. */
private val HEAT = floatArrayOf(0.11f, 0.27f, 0.5f, 0.74f, 1f)

/** Your last five weeks, seven days across and a week to a row; today (bottom right) wears a pulsing ring. */
internal fun fiveWeeks(s: Scene, st: WidgetState, x: Float, y: Float, gw: Float, gh: Float, gap: Float = 3f) {
    val days = st.heat
    val cw = (gw - gap * 6) / 7f
    val ch = (gh - gap * 4) / 5f
    val cell = min(cw, ch)
    val left = x + (gw - (cell * 7 + gap * 6)) / 2f
    val top = y + (gh - (cell * 5 + gap * 4)) / 2f
    for (i in 0 until 35) {
        val n = days[days.size - 35 + i]
        val cx = left + (i % 7) * (cell + gap)
        val cy = top + (i / 7) * (cell + gap)
        s.rect(s.ink(HEAT[heatLevel(n)]), cx, cy, cell, cell, cell * 0.24f)
        if (i == 34) today(s, cx, cy, cell)
    }
}

/** The ring that marks today: your accent, and a second one that swells and fades. */
internal fun today(s: Scene, cx: Float, cy: Float, cell: Float) {
    s.outline(s.accent, cx, cy, cell, cell, cell * 0.24f, 1.6f)
    val ring = cell * 2.1f
    s.sprite(Fx.PULSE, cx + cell / 2f - ring / 2f, cy + cell / 2f - ring / 2f, ring, ring, s.look.accent) { }
}

/** The last [weeks] weeks as columns (Monday at the top), the newest week on the right, today ringed. */
internal fun weeksGrid(s: Scene, st: WidgetState, weeks: Int, x: Float, y: Float, gw: Float, gh: Float, gap: Float) {
    val days = st.heat
    val wd = weekdayOf(st.today)
    val cw = (gw - gap * (weeks - 1)) / weeks
    val ch = (gh - gap * 6) / 7f
    val cell = min(cw, ch)
    val left = x + (gw - (cell * weeks + gap * (weeks - 1))) / 2f
    val top = y + (gh - (cell * 7 + gap * 6)) / 2f
    for (c in 0 until weeks) {
        for (r in 0 until 7) {
            val ago = (weeks - 1 - c) * 7 + (wd - r)
            if (ago < 0) continue
            val idx = days.size - 1 - ago
            if (idx < 0) continue
            val cx = left + c * (cell + gap)
            val cy = top + r * (cell + gap)
            s.rect(s.ink(HEAT[heatLevel(days[idx])]), cx, cy, cell, cell, cell * 0.2f)
            if (ago == 0) today(s, cx, cy, cell)
        }
    }
}

/**
 * Activity: the study heatmap from the back of the membership card. 2 columns show the last five weeks; wider
 * widgets show as many weeks as fit, up to sixteen. Today wears a ring. Tap: your profile.
 */
class ActivityWidget : SceneWidget() {
    override val kind = "activity"
    override val natural = Surface.INK
    override val cells = listOf(4 to 2, 2 to 2, 3 to 2)

    override fun draw(s: Scene, st: WidgetState, id: Int) {
        s.anywhere = open(s.ctx, "memorycard://profile")
        s.description = "Study activity. ${st.streak}-day streak, ${grouped(st.totalSwipes)} swipes."
        if (s.w < 200f) narrow(s, st) else wide(s, st)
    }

    /** 2×2: five weeks, the streak, your best and your swipes. */
    private fun narrow(s: Scene, st: WidgetState) {
        val pad = 14f
        s.text(s.ink(Shade.MUTED), "LAST 5 WEEKS", pad, pad + 9f, 10f, s.uiBold, spacing = 1.1f)
        val foot = 40f
        fiveWeeks(s, st, pad - 2f, pad + 20f, s.w - pad * 2 + 4f, s.h - pad - 20f - foot - pad)
        val fy = s.h - pad - foot + 4f
        flameMark(s, st, pad, fy + 1f, 14f, 17f)
        s.text(s.ink(), if (st.streak == 0) "No streak" else "${st.streak}-day streak", pad + 20f, fy + 15f, 19f, s.display, maxW = s.w - pad * 2 - 20f)
        s.text(s.ink(Shade.MUTED), "best ${st.best} · ${grouped(st.totalSwipes)} swipes", pad, fy + 33f, 11.5f, s.uiBold, maxW = s.w - pad * 2)
    }

    /** 3×2 and 4×2: as many weeks as fit, with the totals along the bottom. */
    private fun wide(s: Scene, st: WidgetState) {
        val pad = 14f
        val iw = s.w - pad * 2
        val weeks = ((iw + 3.5f) / (15f + 3.5f)).toInt().coerceIn(8, 16)
        s.text(s.ink(Shade.MUTED), "LAST $weeks WEEKS", pad, pad + 9f, 10f, s.uiBold, spacing = 1.1f)
        s.text(s.ink(Shade.MUTED), "${grouped(st.totalSwipes)} swipes", s.w - pad, pad + 10f, 12f, s.uiBold, Align.END)
        val foot = 26f
        weeksGrid(s, st, weeks, pad, pad + 22f, iw, s.h - pad - 22f - foot - 8f, 3.5f)
        val fy = s.h - pad - 3f
        flameMark(s, st, pad, fy - 14f, 12f, 14f)
        var x = pad + 17f
        x += s.text(s.ink(), if (st.streak == 0) "No streak yet" else "${st.streak}-day streak", x, fy - 1f, 12.5f, s.uiBold) + 14f
        st.health?.let { x += s.text(s.ink(Shade.MUTED), "${(it * 100).roundToInt()}% health", x, fy - 1f, 12.5f, s.uiBold) + 14f }
        if (s.w - x > 60f) s.text(s.ink(Shade.MUTED), "${st.mastered} mastered", x, fy - 1f, 12.5f, s.uiBold, maxW = s.w - x - pad)
    }
}
