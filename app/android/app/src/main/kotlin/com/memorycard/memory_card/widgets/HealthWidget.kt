package com.memorycard.memory_card.widgets

import android.util.SizeF
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Memory health: how much of your library you would recall right now, and how many cards are slipping. Recall only
 * falls while you are away, so the app writes the next 48 hours ahead and the numbers stay right with the app
 * closed. 2×1 is a number and a bar; 2×2 a ring. Tap: Memory Lab.
 */
class HealthWidget : SceneWidget() {
    override val kind = "health"
    override val natural = Surface.PAPER
    override val cells = listOf(2 to 2, 2 to 1)

    override fun draw(s: Scene, st: WidgetState, id: Int) {
        s.anywhere = open(s.ctx, "memorycard://lab")
        val hp = st.health
        val pct = hp?.let { (it * 100).roundToInt() }
        val slipping = st.slippingNow
        s.description = if (pct == null) "Memory health: nothing learned yet" else "Memory health $pct percent, $slipping cards slipping."
        if (s.h < 130f) small(s, pct, hp, slipping) else ring(s, st, pct, hp, slipping)
    }

    private fun small(s: Scene, pct: Int?, hp: Double?, slipping: Int) {
        val pad = 12f
        s.text(s.ink(), "Memory health", pad, pad + 11f, 12.5f, s.uiBold, maxW = s.w - pad * 2)
        val big = if (pct == null) "—" else "$pct%"
        val bw = s.text(s.ink(), big, pad, s.h / 2f + 14f, 32f, s.display)
        s.text(s.ink(Shade.MUTED), "$slipping slipping", pad + bw + 6f, s.h / 2f + 13f, 11.5f, s.uiBold, maxW = s.w - pad * 2 - bw - 6f)
        s.rect(s.ink(Shade.TRACK), pad, s.h - pad - 6f, s.w - pad * 2, 6f, 3f)
        if (hp != null) s.rect(s.ink(), pad, s.h - pad - 6f, (s.w - pad * 2) * hp.toFloat().coerceIn(0f, 1f), 6f, 3f)
    }

    private fun ring(s: Scene, st: WidgetState, pct: Int?, hp: Double?, slipping: Int) {
        val size = min(100f, s.w - 28f)
        val cx = s.w / 2f
        val top = max(12f, (s.h - (size + 10f + 14f + 6f + 32f)) / 2f)
        val cy = top + size / 2f
        // A breath of light around the ring, every couple of seconds.
        val halo = size * 1.12f
        s.sprite(Fx.PULSE, cx - halo / 2f, cy - halo / 2f, halo, halo, s.look.accent) { }
        val r = size * 0.4f
        s.ring(s.ink(Shade.TRACK), cx, cy, r, size * 0.09f)
        if (hp != null) s.arc(s.ink(), cx, cy, r, size * 0.09f, -90f, 360f * hp.toFloat().coerceIn(0f, 1f))
        s.text(s.ink(), if (pct == null) "—" else "$pct%", cx, cy, size * 0.28f, s.display, Align.CENTER, middle = true)
        val y = top + size + 14f
        s.text(s.ink(), "Memory health", cx, y, 13.5f, s.uiBold, Align.CENTER, maxW = s.w - 16f)
        val tomorrow = st.forecast.getOrElse(1) { 0 }
        s.text(s.ink(Shade.MUTED), "$slipping slipping now", cx, y + 17f, 12f, s.ui, Align.CENTER, maxW = s.w - 16f)
        s.text(s.ink(Shade.MUTED), "$tomorrow more tomorrow", cx, y + 32f, 12f, s.ui, Align.CENTER, maxW = s.w - 16f)
    }
}
