package com.memorycard.memory_card.widgets

import android.util.SizeF
import kotlin.math.max
import kotlin.math.min

/** The day's seal: soft with a progress ring, or pressed red once the goal is met. It turns, very slowly. */
internal fun sealMark(s: Scene, st: WidgetState, cx: Float, cy: Float, size: Float, label: Boolean) {
    val x = cx - size / 2f
    val y = cy - size / 2f
    if (st.goalHit) {
        s.sprite(Fx.SEAL, x, y, size, size, s.look.accent, s.look.accent) { s.seal(s.accent, cx, cy, size) }
        s.ring(s.col(0x80F1F1F1.toInt()), cx, cy, size * 0.33f, size * 0.018f)
        s.ring(s.col(0x59F1F1F1), cx, cy, size * 0.28f, size * 0.011f)
        if (label) {
            val stamp = size * 0.2f
            s.rotated(s.col(Hue.PAPER), -12f, cx, cy) {
                s.text(s.col(Hue.PAPER), "DONE", cx, cy, stamp, s.display, Align.CENTER, spacing = stamp * 0.05f, middle = true)
            }
        }
    } else {
        val (day, night) = s.shade(Shade.SOFT)
        s.sprite(Fx.SEAL, x, y, size, size, day, night) { s.seal(s.ink(Shade.SOFT), cx, cy, size) }
        val stroke = size * if (size < 56f) 0.07f else 0.05f
        s.ring(s.ink(Shade.LINE), cx, cy, size * 0.34f, stroke)
        val frac = (st.done.toFloat() / max(1, st.goal)).coerceIn(0f, 1f)
        if (frac > 0f) s.arc(s.accent, cx, cy, size * 0.34f, stroke, -90f, 360f * frac)
        if (label) s.text(s.ink(), "${st.done}/${st.goal}", cx, cy, size * 0.235f, s.display, Align.CENTER, maxW = size * 0.6f, middle = true)
    }
}

/**
 * Daily goal seal: today's cards against your goal; the red seal once it is met. Tap: study the last deck.
 * One widget that resizes: 2×2 by default, down to the slim 2×1 bar or the 1×1 pill (1×2 is the pill, taller).
 */
class SealWidget : SceneWidget() {
    override val kind = "seal"
    override val natural = Surface.PAPER
    override val cells = listOf(2 to 2, 2 to 1, 1 to 1)

    override fun draw(s: Scene, st: WidgetState, id: Int) {
        val hit = st.goalHit
        s.description = if (hit) "Goal reached: ${st.done} cards today" else "${st.left} of ${st.goal} cards to go today"
        when {
            s.w < 100f -> pill(s, st, hit)
            s.h < 130f -> wide(s, st, hit)
            else -> big(s, st, hit)
        }
    }

    /** 1×1: the seal, what is left, and "to go" (one column wide and two tall: the same, larger). */
    private fun pill(s: Scene, st: WidgetState, hit: Boolean) {
        val roomy = s.h >= 130f
        val seal = if (roomy) min(s.w * 0.72f, 58f) else min(s.w * 0.62f, min(s.h - 42f, 48f))
        val numberSize = if (roomy) 28f else 22f
        val total = seal + 5f + numberSize * 0.72f + 6f + 7f
        val top = (s.h - total) / 2f - 1.5f
        sealMark(s, st, s.w / 2f, top + seal / 2f, seal, label = false)
        val base = top + seal + 5f + numberSize * 0.72f
        s.text(s.ink(), if (hit) "Done" else "${st.left}", s.w / 2f, base, numberSize, s.display, Align.CENTER, maxW = s.w - 12f)
        s.text(s.ink(Shade.MUTED), if (hit) "GOAL MET" else "TO GO", s.w / 2f, base + 6f + 7f, 8.5f, s.uiBold, Align.CENTER, spacing = 0.9f, maxW = s.w - 18f)
    }

    /** 2×1: the seal beside what is left. */
    private fun wide(s: Scene, st: WidgetState, hit: Boolean) {
        val seal = min(64f, s.h - 22f)
        val big = if (hit) "Done" else "${st.left}"
        val sub = if (!st.ready) "to go" else if (hit) "goal met" else "to go"
        val textW = max(s.measure(big, 30f), s.measure(sub, 12f, s.uiBold))
        val group = seal + 10f + textW
        val x0 = max(10f, (s.w - group) / 2f)
        val cy = s.h / 2f
        sealMark(s, st, x0 + seal / 2f, cy, seal, label = true)
        val tx = x0 + seal + 10f
        s.text(s.ink(), big, tx, cy + 4f, 30f, s.display, maxW = s.w - tx - 8f)
        s.text(s.ink(Shade.MUTED), sub, tx, cy + 21f, 12f, s.uiBold, maxW = s.w - tx - 8f)
    }

    /** 2×2: the seal, "8 to go", and what you were studying. */
    private fun big(s: Scene, st: WidgetState, hit: Boolean) {
        val seal = min(92f, s.w - 24f)
        val title = if (hit) "Goal met" else "${st.left} to go"
        val sub = when {
            !st.ready -> "Open Memory Card once to start"
            hit -> "Anything more is a bonus"
            else -> listOfNotNull(st.lastDeck, if (st.minutes > 0) "${st.minutes} min" else null).joinToString(" · ").ifEmpty { "of ${st.goal} today" }
        }
        val titleSize = 27f
        val subHeight = if (s.measure(sub, 12.5f, s.ui) <= s.w - 20f) 14f else 28f
        val total = seal + 7f + titleSize * 0.72f + 7f + subHeight
        val top = max(8f, (s.h - total) / 2f)
        sealMark(s, st, s.w / 2f, top + seal / 2f, seal, label = true)
        val base = top + seal + 7f + titleSize * 0.72f
        s.text(s.ink(), title, s.w / 2f, base, titleSize, s.display, Align.CENTER, maxW = s.w - 14f)
        s.lines(s.ink(Shade.MUTED), sub, 10f, base + 7f, s.w - 20f, 12.5f, s.ui, 2, Align.CENTER, 1.12f)
    }
}
