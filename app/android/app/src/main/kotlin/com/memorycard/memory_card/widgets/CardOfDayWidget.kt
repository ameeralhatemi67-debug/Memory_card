package com.memorycard.memory_card.widgets

import android.graphics.Typeface
import android.net.Uri
import android.util.SizeF
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Card of the day: one card you know cold, prompt and answer, and a new one every few hours. Only mastered cards
 * are used, so seeing an answer never spoils a review that is due. A change turns the card over.
 * Tap: that card's deck.
 */
class CardOfDayWidget : SceneWidget() {
    override val kind = "cotd"
    override val natural = Surface.PAPER
    override val turns = true
    override val cells = listOf(4 to 2, 4 to 1)

    override fun draw(s: Scene, st: WidgetState, id: Int) {
        val c = st.cardOfTheDay
        if (c == null) return empty(s, st)
        s.anywhere = open(s.ctx, "memorycard://study?deck=${Uri.encode(c.deck)}")
        s.description = "Card of the day: ${c.front}, ${c.back}."
        val face = if (c.mono) Typeface.create(Typeface.MONOSPACE, Typeface.BOLD) else s.display
        when {
            s.w < 215f -> compact(s, c, face)
            s.h < 130f -> row(s, c, face)
            else -> card(s, c, face)
        }
    }

    private fun empty(s: Scene, st: WidgetState) {
        s.description = "Card of the day: none yet."
        val cy = s.h / 2f
        s.text(s.ink(Shade.MUTED), "CARD OF THE DAY", s.w / 2f, cy - 10f, 10f, s.uiBold, Align.CENTER, spacing = 1.1f)
        s.text(s.ink(), if (st.ready) "Nothing mastered yet" else "Open Memory Card once", s.w / 2f, cy + 14f, 22f, s.display, Align.CENTER, maxW = s.w - 24f)
        if (s.h > 100f) s.lines(s.ink(Shade.MUTED), "Cards you know cold show up here.", 14f, cy + 22f, s.w - 28f, 12f, s.ui, 2, Align.CENTER)
    }

    /** 4×1: the prompt, a rule, the answer. */
    private fun row(s: Scene, c: DayCard, face: Typeface) {
        val pad = 16f
        val half = (s.w - pad * 2 - 20f) / 2f
        s.text(s.ink(Shade.MUTED), "CARD OF THE DAY", pad, pad + 8f, 10f, s.uiBold, spacing = 1.1f, maxW = half)
        s.linesMiddle(s.ink(), c.front, pad, pad + 14f, half, s.h - pad * 2 - 14f, Art.fit(c.front, 30f), face, 2, lineHeight = 1.0f)
        val rx = pad + half + 10f
        s.rect(s.ink(Shade.LINE), rx, pad, 1f, s.h - pad * 2, 0.5f)
        val tx = rx + 11f
        val tw = s.w - tx - pad
        val back = s.linesHeight(c.back, tw, 16f, s.uiBold, 2)
        val top = (s.h - back - 18f) / 2f
        s.lines(s.ink(), c.back, tx, top, tw, 16f, s.uiBold, 2)
        s.text(s.ink(Shade.MUTED), "${shortDeck(c.deckName)} · mastered", tx, top + back + 16f, 11.5f, s.uiBold, maxW = tw)
    }

    /** 4×2: the prompt, the answer on a soft panel with its hook, the deck and how sure the engine is. */
    private fun card(s: Scene, c: DayCard, face: Typeface) {
        val pad = 16f
        val iw = s.w - pad * 2
        val label = if (c.label.isNotEmpty()) "CARD OF THE DAY · ${c.label.uppercase()}" else "CARD OF THE DAY"
        s.text(s.ink(Shade.MUTED), label, pad, pad + 8f, 10f, s.uiBold, spacing = 1.1f, maxW = iw)
        val footer = 18f
        val hookH = if (c.hook.isNotEmpty()) 4f + min(32f, s.linesHeight(c.hook, iw - 24f, 12.5f, s.uiItalic, 2)) else 0f
        val boxH = 12f + 22f * 0.9f + hookH + 8f
        val boxTop = s.h - pad - footer - 8f - boxH
        s.linesMiddle(s.ink(), c.front, pad, pad + 16f, iw, boxTop - 6f - (pad + 16f), Art.fit(c.front, 38f), face, 2, lineHeight = 1.0f)
        val r = s.look.inner(12f)
        s.rect(s.ink(Shade.SOFT), pad, boxTop, iw, boxH, r)
        s.text(s.ink(), c.back, pad + 12f, boxTop + 12f + 22f * 0.72f, Art.fit(c.back, 22f), s.display, maxW = iw - 24f)
        if (c.hook.isNotEmpty()) s.lines(s.ink(Shade.MUTED), c.hook, pad + 12f, boxTop + 12f + 22f * 0.9f + 4f, iw - 24f, 12.5f, s.uiItalic, 2)
        val fy = s.h - pad - 3f
        s.text(s.ink(Shade.MUTED), c.deckName, pad, fy, 12f, s.uiBold, maxW = iw * 0.6f)
        val recall = "${(c.recall * 100).roundToInt()}% recall"
        val rw = s.text(s.ink(Shade.MUTED), recall, s.w - pad, fy, 12f, s.uiBold, Align.END)
        s.circle(s.col(Hue.GOOD), s.w - pad - rw - 9f, fy - 4f, 3.2f)
        val ring = 16f
        s.sprite(Fx.PULSE, s.w - pad - rw - 9f - ring / 2f, fy - 4f - ring / 2f, ring, ring, Hue.GOOD) { }
    }

    /** Narrow: the prompt over the answer. */
    private fun compact(s: Scene, c: DayCard, face: Typeface) {
        val pad = 12f
        val iw = s.w - pad * 2
        s.text(s.ink(Shade.MUTED), "CARD OF THE DAY", pad, pad + 8f, 9.5f, s.uiBold, spacing = 1f, maxW = iw)
        val mid = s.h * 0.46f
        s.linesMiddle(s.ink(), c.front, pad, pad + 16f, iw, mid - pad - 16f, Art.fit(c.front, 30f), face, 2, lineHeight = 1.0f)
        s.rect(s.ink(Shade.LINE), pad, mid + 4f, iw, 1f, 0.5f)
        s.lines(s.ink(), c.back, pad, mid + 14f, iw, 16f, s.uiBold, 3)
        s.text(s.ink(Shade.MUTED), shortDeck(c.deckName), pad, s.h - pad, 11.5f, s.uiBold, maxW = iw)
    }

    /** "German · A1 Basics" → "German". */
    private fun shortDeck(name: String) = name.substringBefore(" · ").ifEmpty { name }

}
