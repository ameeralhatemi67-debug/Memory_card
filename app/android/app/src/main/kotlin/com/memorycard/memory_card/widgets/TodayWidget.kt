package com.memorycard.memory_card.widgets

import android.util.SizeF
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** The day's answers as one bar: Again, Hard, Good, Easy, sharing rounded ends. */
internal fun gradeBar(s: Scene, st: WidgetState, x: Float, y: Float, w: Float, h: Float) {
    val parts = listOf(
        st.fail to s.col(Hue.AGAIN),
        st.hard to s.col(Hue.PEACH),
        st.good to s.ink(),
        st.easy to s.col(Hue.GOOD),
    ).filter { it.first > 0 }
    if (parts.isEmpty()) {
        s.rect(s.ink(Shade.TRACK), x, y, w, h, h / 2f)
        return
    }
    val total = parts.sumOf { it.first }.toFloat()
    val gap = 2f
    val room = w - gap * (parts.size - 1)
    s.clipped(x, y, w, h, h / 2f) {
        var at = x
        for ((n, brush) in parts) {
            val pw = room * n / total
            s.rect(brush, at, y, pw, h)
            at += pw + gap
        }
    }
}

/** A line of coloured dots with their counts under the grade bar. */
internal fun gradeLegend(s: Scene, st: WidgetState, x: Float, y: Float) {
    var at = x
    for ((n, label, brush) in listOf(
        Triple(st.fail, "again", s.col(Hue.AGAIN)),
        Triple(st.hard, "hard", s.col(Hue.PEACH)),
        Triple(st.good, "good", s.ink()),
        Triple(st.easy, "easy", s.col(Hue.GOOD)),
    )) {
        s.circle(brush, at + 4f, y - 3.5f, 4f)
        val text = "$n $label"
        val tw = s.text(s.ink(Shade.MUTED), text, at + 11f, y, 11.5f, s.uiBold)
        at += 11f + tw + 11f
    }
}

/**
 * Today at a glance: the goal seal, what is left, how the answers went, the streak and the library's health.
 * 4×2 puts the seal beside the numbers; 4×3 adds the health bar and a "Keep going" button. Tap: study.
 */
class TodayWidget : SceneWidget() {
    override val kind = "today"
    override val natural = Surface.PAPER
    override val cells = listOf(4 to 2, 4 to 3)

    override fun draw(s: Scene, st: WidgetState, id: Int) {
        val hit = st.goalHit
        s.description = (if (hit) "Goal reached" else "${st.left} to go") +
            ". ${st.done} reviewed, ${st.ok} remembered, ${st.fail} relearned. ${st.streak}-day streak."
        when {
            s.h >= 250f && s.w >= 230f -> tall(s, st)
            s.h < 125f -> bar(s, st)
            else -> wide(s, st)
        }
    }

    private fun title(st: WidgetState) = if (st.goalHit) "Goal reached" else "${st.left} to go"

    private fun deckLine(st: WidgetState) = listOfNotNull(st.lastDeck, if (st.minutes > 0) "${st.minutes} min" else null)
        .joinToString(" · ").ifEmpty { if (st.ready) "of ${st.goal} today" else "Open Memory Card once to start" }

    /** The streak line: the flame, then "14-day streak". */
    private fun streakLine(s: Scene, st: WidgetState, x: Float, baseline: Float, size: Float) {
        flameMark(s, st, x, baseline - size * 1.0f, size * 0.85f, size)
        s.text(s.ink(), if (st.streak == 0) "No streak yet" else "${st.streak}-day streak", x + size + 4f, baseline - 1f, size * 0.98f, s.uiBold)
    }

    /** One row (4×1 or less): the seal and what is left. */
    private fun bar(s: Scene, st: WidgetState) {
        val seal = min(64f, s.h - 20f)
        sealMark(s, st, 16f + seal / 2f, s.h / 2f, seal, label = true)
        val x = 16f + seal + 14f
        s.text(s.ink(), title(st), x, s.h / 2f + 2f, 28f, s.display, maxW = s.w - x - 14f)
        s.text(s.ink(Shade.MUTED), deckLine(st), x, s.h / 2f + 20f, 12.5f, s.ui, maxW = s.w - x - 14f)
    }

    /** 4×2: the seal on the left; the title, the streak, three numbers and the answers on the right. */
    private fun wide(s: Scene, st: WidgetState) {
        val u = (s.h / 175f).coerceIn(0.9f, 1.25f)
        val pad = 16f
        val seal = min(s.h - pad * 2, 118f * u)
        sealMark(s, st, pad + seal / 2f, s.h / 2f, seal, label = true)
        val x = pad + seal + 16f
        val rw = s.w - x - pad
        val titleSize = 31f * u
        val blocks = 3
        val top = pad + 2f
        val bottom = s.h - pad
        // Title and its lines; the three numbers; the bar: spread over the height.
        val titleH = titleSize * 0.72f + 6f + 15f + 8f + 16f
        val statsH = 22f * u * 0.72f + 4f + 12f
        val barH = 8f * u
        val gap = max(6f, (bottom - top - titleH - statsH - barH) / (blocks - 1))
        s.text(s.ink(), title(st), x, top + titleSize * 0.72f, titleSize, s.display, maxW = rw)
        s.text(s.ink(Shade.MUTED), deckLine(st), x, top + titleSize * 0.72f + 6f + 12f, 12.5f, s.ui, maxW = rw)
        streakLine(s, st, x, top + titleH - 1f, 13f)
        val statsTop = top + titleH + gap
        stats(s, st, x, statsTop, rw, 22f * u)
        gradeBar(s, st, x, bottom - barH, rw, barH)
    }

    /** Three numbers across: reviewed, remembered, relearned. */
    private fun stats(s: Scene, st: WidgetState, x: Float, top: Float, w: Float, numSize: Float) {
        val items = listOf(st.done to "reviewed", st.ok to "remembered", st.fail to "relearned")
        val widths = items.map { max(s.measure("${it.first}", numSize), s.measure(it.second, 11.5f, s.uiBold)) }
        val gap = ((w - widths.sum()) / 2f).coerceAtLeast(6f)
        var at = x
        for ((i, pair) in items.withIndex()) {
            s.text(s.ink(), "${pair.first}", at, top + numSize * 0.72f, numSize, s.display)
            s.text(s.ink(Shade.MUTED), pair.second, at, top + numSize * 0.72f + 14f, 11.5f, s.uiBold)
            at += widths[i] + gap
        }
    }

    /** 4×3: seal and title above; the numbers, the answers with their legend, the health bar and "Keep going". */
    private fun tall(s: Scene, st: WidgetState) {
        val pad = 16f
        val iw = s.w - pad * 2
        // Stacked from the bottom up, so a shorter widget squeezes the seal, never the buttons.
        val button = 40f
        val buttonTop = s.h - pad - button
        val healthTop = buttonTop - 12f - 28f
        val legendBase = healthTop - 9f
        val barTop = legendBase - 14f - 9f
        val tileH = 46f
        val tileTop = barTop - 12f - tileH
        val seal = min(96f, tileTop - 12f - pad).coerceAtLeast(64f)
        sealMark(s, st, pad + seal / 2f, pad + seal / 2f, seal, label = true)
        val x = pad + seal + 14f
        val scale = (seal / 96f).coerceIn(0.8f, 1f)
        s.text(s.ink(), title(st), x, pad + 34f * scale, 33f * scale, s.display, maxW = s.w - x - pad)
        s.text(s.ink(Shade.MUTED), deckLine(st), x, pad + 54f * scale, 12.5f, s.ui, maxW = s.w - x - pad)
        streakLine(s, st, x, pad + 78f * scale, 14f)

        val tw = (iw - 16f) / 3f
        for ((i, pair) in listOf(st.done to "reviewed", st.ok to "remembered", st.fail to "relearned").withIndex()) {
            val tx = pad + i * (tw + 8f)
            s.rect(s.ink(Shade.SOFT), tx, tileTop, tw, tileH, s.look.inner(12f))
            s.text(s.ink(), "${pair.first}", tx + 10f, tileTop + 8f + 22f * 0.72f + 1f, 22f, s.display)
            s.text(s.ink(Shade.MUTED), pair.second, tx + 10f, tileTop + tileH - 8f, 11.5f, s.uiBold, maxW = tw - 14f)
        }
        gradeBar(s, st, pad, barTop, iw, 9f)
        gradeLegend(s, st, pad, legendBase)
        val hp = st.health
        s.text(s.ink(), "Memory health", pad, healthTop + 12f, 13f, s.uiBold)
        s.text(s.ink(), if (hp == null) "—" else "${(hp * 100).roundToInt()}%", pad + iw, healthTop + 14f, 20f, s.display, Align.END)
        s.rect(s.ink(Shade.TRACK), pad, healthTop + 22f, iw, 6f, 3f)
        if (hp != null) s.rect(s.ink(), pad, healthTop + 22f, iw * hp.toFloat().coerceIn(0f, 1f), 6f, 3f)
        val r = s.look.inner(20f)
        s.rect(s.ink(), pad, buttonTop, iw, button, r)
        s.text(s.onInk(), "Keep going", s.w / 2f, buttonTop + button / 2f, 20f, s.display, Align.CENTER, middle = true)
        s.hit(pad, buttonTop, iw, button, SceneWidget.open(s.ctx, "memorycard://study"), "Keep going", r)
    }
}
