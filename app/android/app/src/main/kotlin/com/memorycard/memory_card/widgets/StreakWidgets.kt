package com.memorycard.memory_card.widgets

import android.util.SizeF
import com.memorycard.memory_card.R
import kotlin.math.min

/**
 * The flame, flickering; an outline of it while the streak waits for today (or has not started). [still] draws it
 * on the page instead of as a moving piece, for a face that turns over (a moving piece does not turn with the page).
 */
internal fun flameMark(s: Scene, st: WidgetState, x: Float, y: Float, fw: Float, fh: Float, still: Boolean = false) {
    val waiting = st.atRisk || st.streak == 0
    val fx = if (waiting) Fx.FLAME_OUTLINE else Fx.FLAME
    val draw = { s.vec(s.accent, if (waiting) R.drawable.wg_fx_flame_outline_vd else R.drawable.wg_fx_flame_vd, x, y, fw, fh) }
    if (still) draw() else s.sprite(fx, x, y, fw, fh, s.look.accent) { draw() }
}

/** The grace shields left this month, drawn at [x],[y] one after the other. */
internal fun shieldRow(s: Scene, st: WidgetState, x: Float, y: Float, sw: Float, sh: Float, gap: Float, leftToRight: Boolean = true) {
    for (i in 0 until 2) {
        val full = st.shields >= i + 1
        val at = if (leftToRight) x + i * (sw + gap) else x - (i + 1) * sw - i * gap
        s.vec(s.col(Hue.BLUE), if (full) R.drawable.wg_shield else R.drawable.wg_shield_outline, at, y, sw, sh, tint = false)
    }
}

/** This week, Monday first: filled when the goal was met, your accent around today, and the days to come faint. */
internal fun weekRow(s: Scene, st: WidgetState, x: Float, y: Float, cell: Float, gap: Float) {
    val wd = weekdayOf(st.today)
    for (i in 0 until 7) {
        val day = st.today - wd + i
        val cx = x + i * (cell + gap)
        val r = cell * 0.3f
        when {
            day > st.today -> s.rect(s.ink(0.14f), cx, y, cell, cell, r)
            day == st.today -> {
                if (st.goalHit) s.rect(s.ink(), cx, y, cell, cell, r)
                s.outline(s.accent, cx, y, cell, cell, r, 1.6f)
            }
            day in st.goalDays -> s.rect(s.ink(), cx, y, cell, cell, r)
            else -> s.rect(s.ink(0.26f), cx, y, cell, cell, r)
        }
    }
}

/**
 * Streak flame: the streak and this month's grace shields; with room it shows this week and your best too.
 * After 18:00 with the goal not met, it asks for today. Tap: Today.
 * One row tall, 1 to 4 columns wide.
 */
class StreakWidget : SceneWidget() {
    override val kind = "streak"
    override val natural = Surface.INK
    override val cells = listOf(2 to 1, 1 to 1, 3 to 1, 4 to 1)

    override fun draw(s: Scene, st: WidgetState, id: Int) {
        s.anywhere = open(s.ctx, "memorycard://today")
        s.description = "${st.streak}-day streak, ${st.shields} grace shields left"
        when {
            s.w < 100f -> pill(s, st)
            s.w < 215f -> medium(s, st)
            else -> wide(s, st)
        }
    }

    /** 1×1: flame, days, "days". */
    private fun pill(s: Scene, st: WidgetState) {
        val n = st.streak
        val numberSize = 25f
        val total = 22f + 3f + numberSize * 0.72f + 5f + 7f
        val top = (s.h - total) / 2f
        flameMark(s, st, s.w / 2f - 9f, top, 18f, 22f)
        val base = top + 22f + 3f + numberSize * 0.72f
        s.text(s.ink(), "$n", s.w / 2f, base, numberSize, s.display, Align.CENTER, maxW = s.w - 10f)
        s.text(s.ink(Shade.MUTED), "DAYS", s.w / 2f, base + 5f + 7f, 9f, s.uiBold, Align.CENTER, spacing = 1.1f)
    }

    /** 2×1: flame and shields above, the number below, and (when there is height) this week and your best. */
    private fun medium(s: Scene, st: WidgetState) {
        val n = st.streak
        val pad = 12f
        val withWeek = s.h >= 84f
        val sub = when {
            n == 0 -> "start today"
            st.atRisk -> "study today"
            else -> "day streak"
        }
        val top = if (withWeek) 8f else pad
        flameMark(s, st, pad, top, 17f, 21f)
        shieldRow(s, st, s.w - pad, top + 3f, 11f, 13f, 3f, leftToRight = false)
        val numberSize = if (withWeek) 33f else 38f
        val base = if (withWeek) s.h - 30f else s.h - pad - 4f
        val nw = s.text(s.ink(), "$n", pad, base, numberSize, s.display)
        s.text(s.ink(Shade.MUTED), sub, pad + nw + 6f, base - 2f, 12.5f, s.uiBold, maxW = s.w - pad * 2 - nw - 6f)
        if (withWeek) {
            val cell = min(11f, (s.w - pad * 2 - 6 * 3.5f - 46f) / 7f)
            weekRow(s, st, pad, s.h - pad - cell + 1f, cell, 3.5f)
            if (st.best > 0) s.text(s.ink(Shade.MUTED), "best ${st.best}", s.w - pad, s.h - pad + 0.5f, 11f, s.uiBold, Align.END)
        }
    }

    /** 3 to 4 columns: the flame, "14-day streak", the line under it, the shields. */
    private fun wide(s: Scene, st: WidgetState) {
        val n = st.streak
        val pad = 16f
        val cy = s.h / 2f
        flameMark(s, st, pad, cy - 15f, 26f, 30f)
        val big = if (n == 0) "No streak yet" else "$n-day streak"
        val sub = when {
            n == 0 -> "Reach today's goal to start one"
            st.atRisk -> "Study today to keep it"
            else -> "${st.shields} grace ${if (st.shields == 1) "shield" else "shields"} left this month"
        }
        val tx = pad + 26f + 12f
        val shieldsW = 20f * 2 + 4f + 8f
        val textW = s.w - tx - pad - shieldsW
        s.text(s.ink(), big, tx, cy + 1f, 26f, s.display, maxW = textW)
        s.text(s.ink(Shade.MUTED), sub, tx, cy + 20f, 13f, s.ui, maxW = textW)
        shieldRow(s, st, s.w - pad, cy - 12f, 20f, 24f, 4f, leftToRight = false)
    }
}
