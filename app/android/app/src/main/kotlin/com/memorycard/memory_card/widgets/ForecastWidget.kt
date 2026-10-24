package com.memorycard.memory_card.widgets

import android.util.SizeF
import kotlin.math.max
import kotlin.math.min

private val LETTERS = charArrayOf('M', 'T', 'W', 'T', 'F', 'S', 'S')

/**
 * Next two weeks: from Memory Lab, how many cards start slipping on each day if you do not study. Today's bar is
 * your accent colour and carries a small ringing dot. 4×1 shows tomorrow's number and the week ahead as seven bars;
 * 4×2 shows all fourteen days. Tap: Memory Lab.
 */
class ForecastWidget : SceneWidget() {
    override val kind = "forecast"
    override val natural = Surface.PAPER
    override val cells = listOf(4 to 2, 4 to 1)

    override fun draw(s: Scene, st: WidgetState, id: Int) {
        s.anywhere = open(s.ctx, "memorycard://lab")
        val f = st.forecast
        val tomorrow = f.getOrElse(1) { 0 }
        val week = f.drop(1).take(7).sum()
        s.description = "$tomorrow cards start slipping tomorrow, $week in the next week."
        if (s.h < 130f) row(s, st, f, tomorrow, week) else chart(s, st, f, tomorrow, week)
    }

    /** 4×1: tomorrow's number and the next seven days as bars. */
    private fun row(s: Scene, st: WidgetState, f: List<Int>, tomorrow: Int, week: Int) {
        val pad = 16f
        s.text(s.ink(), "$tomorrow", pad, s.h / 2f + 8f, 38f, s.display)
        val textX = pad + s.measure("$tomorrow", 38f) + 12f
        val barsW = min(s.w * 0.4f, 150f)
        val barsX = s.w - pad - barsW
        s.lines(s.ink(Shade.MUTED), "start slipping tomorrow · $week this week", textX, s.h / 2f - 14f, barsX - textX - 12f, 12f, s.ui, 3, lineHeight = 1.15f)
        bars(s, st, f.drop(1).take(7), 1, barsX, 14f, barsW, s.h - 28f, labels = true, barSize = 10f)
    }

    /** 4×2: all fourteen days. */
    private fun chart(s: Scene, st: WidgetState, f: List<Int>, tomorrow: Int, week: Int) {
        val pad = 16f
        s.text(s.ink(), "Next two weeks", pad, pad + 16f, 21f, s.display)
        s.text(s.ink(Shade.MUTED), "Cards that start slipping each day", pad, pad + 33f, 12f, s.ui)
        bars(s, st, f.take(14), 0, pad, pad + 46f, s.w - pad * 2, s.h - pad * 2 - 46f, labels = true, barSize = 12f)
    }

    /** Bars with a weekday letter under each; the first of day 0 is today (accent). */
    private fun bars(s: Scene, st: WidgetState, values: List<Int>, firstDay: Int, x: Float, y: Float, w: Float, h: Float, labels: Boolean, barSize: Float) {
        if (values.isEmpty()) return
        val labelH = if (labels) 14f else 0f
        val maxV = max(1, values.max())
        val pitch = w / values.size
        val top = y + 8f
        val area = h - labelH - 8f
        val wd = weekdayOf(st.today)
        for ((i, v) in values.withIndex()) {
            val day = firstDay + i
            val bw = min(barSize, pitch - 3f)
            val cx = x + pitch * i + pitch / 2f
            val bh = max(3f, area * v / maxV)
            val brush = if (day == 0) s.accent else s.ink()
            s.rect(brush, cx - bw / 2f, top + area - bh, bw, bh, 3f)
            if (day == 0) {
                val ring = bw * 2.2f
                s.circle(s.accent, cx, top + area - bh - 6f, 2.6f)
                s.sprite(Fx.PULSE, cx - ring / 2f, top + area - bh - 6f - ring / 2f, ring, ring, s.look.accent) { }
            }
            if (labels) s.text(s.ink(Shade.MUTED), LETTERS[(wd + day) % 7].toString(), cx, y + h - 2f, 10f, s.uiBold, Align.CENTER)
        }
    }

}
