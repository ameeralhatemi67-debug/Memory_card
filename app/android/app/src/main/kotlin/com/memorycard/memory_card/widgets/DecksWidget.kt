package com.memorycard.memory_card.widgets

import android.net.Uri
import android.util.SizeF
import com.memorycard.memory_card.R
import kotlin.math.min

/** How strongly each step of the progress fan is lit when it is on, as a share of the bar's own paper. */
private val FAN_ON = floatArrayOf(0.5f, 0.62f, 0.74f, 0.87f, 1f)

/**
 * The deck's stepped progress fan, as on a deck bar: five cards fanned from the bottom right corner, one step lit
 * for every fifth of the deck you are strong on. [k] scales the 54×80 dp cards.
 */
internal fun deckFan(s: Scene, steps: Int, barX: Float, barY: Float, barW: Float, barH: Float, radius: Float, k: Float) {
    s.clipped(barX, barY, barW, barH, radius) {
        for (i in 0 until 5) {
            val cornerX = barX + barW - (-10f + (4 - i) * 15f) * k
            val cornerY = barY + barH + (-40f + i * 8f) * k
            val brush = if (i < steps) s.onInk(FAN_ON[i]) else s.onInk(0.1f)
            s.rotated(brush, -16f + i * 3f, cornerX, cornerY) {
                s.rect(brush, cornerX - 54f * k, cornerY - 80f * k, 54f * k, 80f * k, 7f * k)
            }
        }
    }
}

/**
 * Continue a deck: your deck bars with their progress fans, pinned decks first, then the ones you studied most
 * recently. 4×1 holds one deck; 4×2 two; 4×3 the Daily mix and three. Tap a bar to study that deck. A band of
 * light crosses each bar every few seconds.
 */
class DecksWidget : SceneWidget() {
    override val kind = "decks"
    override val natural = Surface.PAPER
    override val cells = listOf(4 to 2, 4 to 1, 4 to 3)

    private fun meta(d: DeckInfo) = when {
        d.slipping > 0 -> "${d.cards} cards · ${d.slipping} slipping"
        d.fresh > 0 -> "${d.cards} cards · ${d.fresh} still new"
        else -> "${d.cards} cards · all strong"
    }

    override fun draw(s: Scene, st: WidgetState, id: Int) {
        val decks = st.decks
        s.description = if (decks.isEmpty()) "No decks yet." else "Decks: " + decks.take(3).joinToString(", ") { it.name }
        if (decks.isEmpty()) return empty(s, st)
        if (s.h < 130f) {
            // One deck: the widget is the bar.
            bar(s, st, decks[0], 0f, 0f, s.w, s.h, s.look.radius, 0)
        } else {
            val pad = 12f
            val iw = s.w - pad * 2
            var y = pad
            val three = s.h >= 250f
            s.text(s.ink(), "Decks", pad + 2f, y + 17f, 20f, s.display)
            val mix = st.mixSlipping
            s.text(s.ink(Shade.MUTED), if (mix > 0) "$mix slipping" else "all strong", s.w - pad - 2f, y + 16f, 12.5f, s.uiBold, Align.END)
            y += 28f
            if (three) {
                dailyMix(s, st, pad, y, iw, 44f)
                y += 44f + 8f
            }
            val count = if (three) 3 else 2
            val bottom = s.h - pad
            val gap = 8f
            val bh = min(88f, (bottom - y - gap * (count - 1)) / count)
            for (i in 0 until min(count, decks.size)) {
                bar(s, st, decks[i], pad, y + i * (bh + gap), iw, bh, s.look.inner(12f), i)
            }
        }
    }

    private fun empty(s: Scene, st: WidgetState) {
        s.text(s.ink(), "No decks yet", s.w / 2f, s.h / 2f + 4f, 24f, s.display, Align.CENTER, maxW = s.w - 24f)
        s.text(s.ink(Shade.MUTED), if (st.ready) "Add a deck in Memory Card" else "Open Memory Card once", s.w / 2f, s.h / 2f + 22f, 12.5f, s.uiBold, Align.CENTER, maxW = s.w - 24f)
    }

    /** One deck bar: ink, with the name, its numbers and the fan. */
    private fun bar(s: Scene, st: WidgetState, d: DeckInfo, x: Float, y: Float, w: Float, h: Float, radius: Float, index: Int) {
        val pi = SceneWidget.open(s.ctx, "memorycard://study?deck=${Uri.encode(d.id)}")
        s.rect(s.ink(), x, y, w, h, radius)
        val k = (h / 88f).coerceIn(0.7f, 1.3f)
        deckFan(s, d.steps, x, y, w, h, radius, k)
        val textW = w - 28f - 96f * k
        val nameSize = (if (h > 100f) 25f else if (h > 70f) 22f else 20f)
        val titleLines = if (h > 100f) 2 else 1
        s.lines(s.onInk(), d.name, x + 16f, y + 12f, textW, nameSize, s.display, titleLines, Align.START, 1.02f)
        s.text(s.onInk(0.74f), meta(d), x + 16f, y + h - 11f, 12.5f, s.uiBold, maxW = textW)
        val (lightDay, lightNight) = s.glint(onMain = true)
        s.sprite(Fx.SHEEN_WIDE, x, y, w, h, lightDay, lightNight) { }
        s.hit(x, y, w, h, pi, "Study ${d.name}", radius)
    }

    /** The Daily mix row: every slipping card across your decks. */
    private fun dailyMix(s: Scene, st: WidgetState, x: Float, y: Float, w: Float, h: Float) {
        val r = s.look.inner(12f)
        s.rect(s.ink(Shade.SOFT), x, y, w, h, r)
        s.vec(s.ink(), R.drawable.wg_logo, x + 12f, y + h / 2f - 11.5f, 18f, 23f)
        s.text(s.ink(), "Daily mix", x + 40f, y + 19f, 18f, s.display, maxW = w - 80f)
        val line = if (st.mixSlipping > 0) "${st.mixSlipping} slipping across ${st.mixDecks} ${if (st.mixDecks == 1) "deck" else "decks"}" else "nothing slipping"
        s.text(s.ink(Shade.MUTED), line, x + 40f, y + 35f, 12f, s.uiBold, maxW = w - 80f)
        s.text(s.ink(Shade.MUTED), "›", x + w - 16f, y + h / 2f + 1f, 22f, s.uiBold, Align.CENTER, middle = true)
        s.hit(x, y, w, h, SceneWidget.open(s.ctx, "memorycard://mix"), "Daily mix", r)
    }
}
