package com.memorycard.memory_card.widgets

import android.util.SizeF
import kotlin.math.min

/**
 * Seals: the latest wax seals you earned, each turning on its own, and the one you are closest to. Two sizes: 4×1
 * (three seals) and 3×1 (two). Tap: the seal gallery.
 */
class SealsWidget : SceneWidget() {
    override val kind = "seals"
    override val natural = Surface.PAPER
    override val cells = listOf(4 to 1, 3 to 1)

    override fun draw(s: Scene, st: WidgetState, id: Int) {
        s.anywhere = open(s.ctx, "memorycard://seals")
        val info = st.seals
        s.description = "${info.earned} of ${info.total} seals earned."
        wide(s, st)
    }

    /** 4×1 shows three seals and the line about the next one; 3×1 shows two, with the name of the next. */
    private fun wide(s: Scene, st: WidgetState) {
        val info = st.seals
        val pad = 16f
        val disc = min(46f, s.h - 28f)
        val shown = if (s.w >= 330f) 3 else 2
        var x = pad
        for (m in info.latest.take(shown)) {
            sealDisc(s, m, x + disc / 2f, s.h / 2f, disc, disc * 0.26f)
            x += disc + 5f
        }
        if (info.latest.isEmpty()) {
            emptyDisc(s, x + disc / 2f, s.h / 2f, disc)
            x += disc + 5f
        }
        x += 8f
        val rw = s.w - x - pad
        s.text(s.ink(), "Seals", x, s.h / 2f - 16f, 13f, s.uiBold)
        s.text(s.ink(), "${info.earned} of ${info.total}", x, s.h / 2f + 10f, 26f, s.display, maxW = rw)
        val next = info.next
        val full = when {
            next != null -> "next: ${next.title} · ${next.left} ${next.unit} to go"
            info.earned >= info.total -> "every seal earned"
            else -> "your first one is close"
        }
        // Without room for how far it is, only its name.
        val line = if (next != null && s.measure(full, 11.5f, s.uiBold) > rw) "next: ${next.title}" else full
        s.text(s.ink(Shade.MUTED), line, x, s.h / 2f + 28f, 11.5f, s.uiBold, maxW = rw)
    }

    /** Nothing earned yet: a quiet outline where the first seal will go. */
    private fun emptyDisc(s: Scene, cx: Float, cy: Float, size: Float) {
        val (day, night) = s.shade(Shade.SOFT)
        s.sprite(Fx.SEAL, cx - size / 2f, cy - size / 2f, size, size, day, night) { s.seal(s.ink(Shade.SOFT), cx, cy, size) }
        s.ring(s.ink(Shade.LINE), cx, cy, size * 0.33f, size * 0.03f)
    }
}
