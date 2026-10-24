package com.memorycard.memory_card.widgets

import android.util.SizeF
import kotlin.math.max
import kotlin.math.min

private val LETTERS = charArrayOf('M', 'T', 'W', 'T', 'F', 'S', 'S')

private val NAMES = arrayOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

/**
 * Next two weeks: from Memory Lab, how many cards start slipping on each day if you do not study. Today's bar is
 * your accent colour and carries a small ringing dot. Two sizes, both four columns wide: 4×2 shows all fourteen days;
 * 4×3 adds tomorrow, the week and the busiest day above them, and the number over each bar. Tap: Memory Lab.
 */
class ForecastWidget : SceneWidget() {
    override val kind = "forecast"
    override val natural = Surface.PAPER
    override val cells = listOf(4 to 2, 4 to 3)

    override fun draw(s: Scene, st: WidgetState, id: Int) {
        s.anywhere = open(s.ctx, "memorycard://lab")
        val f = st.forecast
        val tomorrow = f.getOrElse(1) { 0 }
        val week = f.drop(1).take(7).sum()
        s.description = "$tomorrow cards start slipping tomorrow, $week in the next week."
        if (s.h < 300f) chart(s, st, f) else tall(s, st, f, tomorrow, week)
    }

    /** 4×2: all fourteen days. */
    private fun chart(s: Scene, st: WidgetState, f: List<Int>) {
        val pad = 16f
        s.text(s.ink(), "Next two weeks", pad, pad + 16f, 21f, s.display)
        s.text(s.ink(Shade.MUTED), "Cards that start slipping each day", pad, pad + 33f, 12f, s.ui)
        bars(s, st, f.take(14), 0, pad, pad + 46f, s.w - pad * 2, s.h - pad * 2 - 46f, labels = true, barSize = 12f)
    }

    /** 4×3: the same, with three numbers above the bars and each bar's count over it. */
    private fun tall(s: Scene, st: WidgetState, f: List<Int>, tomorrow: Int, week: Int) {
        val pad = 16f
        s.text(s.ink(), "Next two weeks", pad, pad + 16f, 21f, s.display)
        s.text(s.ink(Shade.MUTED), "Cards that start slipping each day", pad, pad + 33f, 12f, s.ui)
        val days = f.take(14)
        val peak = days.indices.maxByOrNull { days[it] } ?: 0
        val wd = weekdayOf(st.today)
        val peakName = when (peak) {
            0 -> "today"
            1 -> "tomorrow"
            else -> NAMES[(wd + peak) % 7]
        }
        val stats = listOf(
            "$tomorrow" to "tomorrow",
            "$week" to "this week",
            "${days.getOrElse(peak) { 0 }}" to "most, $peakName",
        )
        val top = pad + 52f
        val colW = (s.w - pad * 2) / stats.size
        for ((i, e) in stats.withIndex()) {
            val x = pad + i * colW
            s.text(s.ink(), e.first, x, top + 24f, 30f, s.display, maxW = colW - 6f)
            s.text(s.ink(Shade.MUTED), e.second, x, top + 41f, 12f, s.uiBold, maxW = colW - 6f)
        }
        s.rect(s.ink(Shade.LINE), pad, top + 54f, s.w - pad * 2, 1f, 0.5f)
        val chartTop = top + 70f
        bars(s, st, days, 0, pad, chartTop, s.w - pad * 2, s.h - pad - chartTop, labels = true, barSize = 14f, counts = true)
    }

    /** Bars with a weekday letter under each; the first of day 0 is today (accent). */
    private fun bars(s: Scene, st: WidgetState, values: List<Int>, firstDay: Int, x: Float, y: Float, w: Float, h: Float, labels: Boolean, barSize: Float, counts: Boolean = false) {
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
            if (counts && v > 0) s.text(s.ink(Shade.MUTED), "$v", cx, top + area - bh - (if (day == 0) 14f else 4f), 9.5f, s.uiBold, Align.CENTER, maxW = pitch)
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
