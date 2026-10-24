package com.memorycard.memory_card.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.net.Uri
import android.util.SizeF
import com.memorycard.memory_card.R
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlin.math.max
import kotlin.math.min

/**
 * Quick card: the card you are closest to forgetting, right on the home screen. Reveal turns it over; Again or
 * Got it records the answer in the inbox and brings the next card. The app replays the answers through the
 * engine the next time it opens (AppStore.applyWidgetReviews), so nothing here needs Dart to run.
 * Every change turns the card over, like a card on the table.
 */
class QuickCardWidget : SceneWidget() {
    override val kind = "quick"
    override val natural = Surface.PAPER
    override val turns = true
    override val cells = listOf(4 to 2, 4 to 3)

    /** What one draw needs to know about the card in hand. */
    private class Hand(val s: Scene, val st: WidgetState, val card: QCard, val turned: Boolean, val id: Int) {
        val reveal: PendingIntent get() = action(s.ctx, REVEAL, card.id, id)
        val again: PendingIntent get() = action(s.ctx, AGAIN, card.id, id)
        val good: PendingIntent get() = action(s.ctx, GOOD, card.id, id)
        val deck: PendingIntent get() = SceneWidget.open(s.ctx, "memorycard://study?deck=${Uri.encode(card.deck)}")
        val count: String
            get() {
                val left = st.slippingLeft
                return when {
                    st.reviewedHere > 0 && left > 0 -> "${st.reviewedHere} done · $left left"
                    st.reviewedHere > 0 -> "${st.reviewedHere} done"
                    left > 0 -> "$left slipping"
                    else -> "Review ahead"
                }
            }
    }

    override fun draw(s: Scene, st: WidgetState, id: Int) {
        val card = st.queue.firstOrNull()
        if (!st.ready || card == null) return empty(s, st)
        val turned = st.openCard == card.id
        val hand = Hand(s, st, card, turned, id)
        s.description = if (turned) "${card.front}: ${card.back}. Again or Got it." else "${card.front.ifEmpty { "Picture card" }}. Reveal the answer."
        when {
            s.w < 230f -> compact(hand)
            s.h >= 250f -> tall(hand)
            s.look.quickSide -> side(hand)
            else -> stacked(hand)
        }
    }

    // ---------------------------------------------------------------------------------------------- the four designs

    /** 4×2: deck and count, the prompt with its example, then the buttons. */
    private fun stacked(h: Hand) {
        val s = h.s
        val pad = 14f
        val iw = s.w - pad * 2
        header(h, pad, pad, iw)
        val buttons = s.h - pad - 40f
        val bottom = buttons - 8f
        val top = pad + 22f
        s.text(s.ink(Shade.MUTED), h.card.label.uppercase(), pad, top + 10f, 10f, s.uiBold, spacing = 1f, maxW = iw)
        if (h.turned) {
            val box = min(max(54f, (bottom - top) * 0.46f), 84f)
            front(h, pad, top + 14f, iw, bottom - box - 8f - (top + 14f), 32f, 17f, 1, Align.START, s.ink(), 320)
            answerBox(h, pad, bottom - box, iw, box, 22f, hook = false, center = false)
            grades(h, pad, buttons, iw, 40f, 8f, 15f)
        } else {
            front(h, pad, top + 14f, iw, bottom - 18f - (top + 14f), 32f, 32f, 2, Align.START, s.ink(), 320)
            if (h.card.example.isNotEmpty()) s.text(s.ink(Shade.MUTED), h.card.example, pad, bottom - 4f, 13f, s.uiItalic, maxW = iw)
            revealButton(h, pad, buttons, iw, 40f)
        }
    }

    /** 4×3: an ink face with the prompt, the answer (or its hidden box) below, then the buttons. */
    private fun tall(h: Hand) {
        val s = h.s
        val pad = 16f
        val iw = s.w - pad * 2
        header(h, pad, pad, iw)
        val buttons = s.h - pad - 40f
        val boxH = if (h.turned) min(max(58f, answerNeed(h, iw, 24f)), 112f) else 58f
        val boxTop = buttons - 10f - boxH
        val faceTop = pad + 28f
        val faceH = boxTop - 10f - faceTop
        val r = s.look.inner(14f)
        s.rect(s.ink(), pad, faceTop, iw, faceH, r)
        s.hit(pad, faceTop, iw, faceH, if (h.turned) h.deck else h.reveal, if (h.turned) "Open the deck" else "Reveal", r)
        s.text(s.onInk(0.74f), h.card.label.uppercase(), s.w / 2f, faceTop + 18f, 10f, s.uiBold, Align.CENTER, spacing = 1f, maxW = iw - 20f)
        val exampleRoom = if (!h.turned && h.card.example.isNotEmpty()) 20f else 0f
        front(h, pad + 10f, faceTop + 26f, iw - 20f, faceH - 34f - exampleRoom, 36f, 26f, 2, Align.CENTER, s.onInk(), 360)
        if (exampleRoom > 0f) s.text(s.onInk(0.74f), h.card.example, s.w / 2f, faceTop + faceH - 12f, 12.5f, s.uiItalic, Align.CENTER, maxW = iw - 20f)
        if (h.turned) {
            answerBox(h, pad, boxTop, iw, boxH, 24f, hook = true, center = false)
            grades(h, pad, buttons, iw, 40f, 8f, 15f)
        } else {
            s.outline(s.ink(Shade.TRACK), pad, boxTop, iw, boxH, s.look.inner(12f), 1.5f, 5f, 4f)
            s.text(s.ink(Shade.MUTED), "Answer hidden", s.w / 2f, boxTop + boxH / 2f, 13f, s.uiBold, Align.CENTER, middle = true)
            revealButton(h, pad, buttons, iw, 40f)
        }
    }

    /** 4×2, side by side: the prompt on an ink face, the deck, example and buttons beside it. */
    private fun side(h: Hand) {
        val s = h.s
        val pad = 14f
        val faceW = min(150f, s.w * 0.4f)
        val faceH = s.h - pad * 2
        val r = s.look.inner(14f)
        s.rect(s.ink(), pad, pad, faceW, faceH, r)
        s.hit(pad, pad, faceW, faceH, if (h.turned) h.deck else h.reveal, if (h.turned) "Open the deck" else "Reveal", r)
        s.text(s.onInk(0.74f), h.card.label.uppercase(), pad + faceW / 2f, pad + 20f, 9.5f, s.uiBold, Align.CENTER, spacing = 1f, maxW = faceW - 16f)
        front(h, pad + 8f, pad + 28f, faceW - 16f, faceH - 36f, 30f, 22f, 3, Align.CENTER, s.onInk(), 260)
        val x = pad + faceW + 14f
        val rw = s.w - x - pad
        s.text(s.ink(Shade.MUTED), h.card.deckName, x, pad + 11f, 12.5f, s.uiBold, maxW = rw)
        s.hit(x, pad, rw, 18f, h.deck, h.card.deckName, 6f)
        val buttons = s.h - pad - 38f
        if (h.turned) {
            val hookRoom = h.card.hook.isNotEmpty()
            val top = pad + 22f
            s.linesMiddle(s.ink(), h.card.back, x, top, rw, buttons - top - 8f - (if (hookRoom) 30f else 0f), Art.fit(h.card.back, 24f), s.display, 3, Align.START)
            if (hookRoom) s.lines(s.ink(Shade.MUTED), h.card.hook, x, buttons - 38f, rw, 12f, s.ui, 2)
            grades(h, x, buttons, rw, 38f, 6f, 14f)
        } else {
            if (h.card.example.isNotEmpty()) s.linesMiddle(s.ink(Shade.MUTED), h.card.example, x, pad + 22f, rw, buttons - pad - 30f, 13f, s.uiItalic, 3)
            revealButton(h, x, buttons, rw, 38f)
        }
    }

    /** Smaller than 4 columns (an old 2×2 left on the home screen): the prompt, then the buttons. */
    private fun compact(h: Hand) {
        val s = h.s
        val pad = 12f
        val iw = s.w - pad * 2
        val buttons = s.h - pad - 40f
        val bottom = buttons - 8f
        s.text(s.ink(Shade.MUTED), h.card.label.uppercase(), s.w / 2f, pad + 9f, 9.5f, s.uiBold, Align.CENTER, spacing = 1f, maxW = iw)
        if (h.turned) {
            val box = min(max(48f, answerNeed(h, iw, 20f)), 90f)
            front(h, pad, pad + 16f, iw, bottom - box - 6f - (pad + 16f), 28f, 17f, 1, Align.CENTER, s.ink(), 200)
            answerBox(h, pad, bottom - box, iw, box, 20f, hook = false, center = true)
            grades(h, pad, buttons, iw, 40f, 6f, 13f)
        } else {
            front(h, pad, pad + 16f, iw, bottom - (pad + 16f), 28f, 28f, 3, Align.CENTER, s.ink(), 200)
            revealButton(h, pad, buttons, iw, 40f)
        }
    }

    private fun empty(s: Scene, st: WidgetState) {
        val title = if (st.ready) "All caught up" else "Quick card"
        val sub = if (st.ready) "Nothing to recall here right now.\nOpen Memory Card for more." else "Open Memory Card once to start."
        s.description = "$title. $sub"
        val cy = s.h / 2f
        s.vec(s.ink(), R.drawable.wg_logo, s.w / 2f - 12f, cy - 44f, 24f, 30f)
        s.text(s.ink(), title, s.w / 2f, cy + 6f, 22f, s.display, Align.CENTER, maxW = s.w - 24f)
        s.lines(s.ink(Shade.MUTED), sub, 12f, cy + 16f, s.w - 24f, 12.5f, s.ui, 3, Align.CENTER, 1.15f)
    }

    // ---------------------------------------------------------------------------------------------- the pieces

    private fun header(h: Hand, x: Float, y: Float, w: Float) {
        val s = h.s
        val countW = s.measure(h.count, 12.5f, s.uiBold)
        s.text(s.ink(Shade.MUTED), h.card.deckName, x, y + 11f, 12.5f, s.uiBold, maxW = w - countW - 10f)
        s.text(s.ink(Shade.MUTED), h.count, x + w, y + 11f, 12.5f, s.uiBold, Align.END)
        s.hit(x, y - 2f, w, 20f, h.deck, "Study ${h.card.deckName}", 6f)
    }

    /**
     * The prompt in a box: its picture (blurred or hidden until the reveal when the card asks for it), else its
     * text, stepped down in size to fit and again once the card is turned over.
     */
    private fun front(h: Hand, x: Float, y: Float, w: Float, bh: Float, baseSp: Float, turnedSp: Float, maxLines: Int, align: Align, brush: Brush, pictureMaxPx: Int) {
        if (bh < 8f) return
        val s = h.s
        val card = h.card
        val waits = !h.turned && card.imgReveal != null
        val picture = card.img?.takeUnless { waits && card.imgReveal == "hide" }?.let { Art.picture(s.ctx, it, pictureMaxPx, blur = waits) }
        if (picture != null) {
            s.picture(picture, x, y, w, bh, center = align == Align.CENTER)
            return
        }
        val prompt = card.front.ifEmpty { if (card.img != null) "Picture hidden until you reveal" else "?" }
        var sp = if (card.front.isEmpty()) 15f else Art.fit(prompt, baseSp) * if (card.mono) 0.75f else 1f
        if (h.turned) sp = min(sp, turnedSp)
        val face = if (card.mono) Typeface.create(Typeface.MONOSPACE, Typeface.BOLD) else s.display
        s.linesMiddle(brush, prompt, x, y, w, bh, sp, face, if (h.turned && maxLines == 1) 1 else maxLines, align, 1.02f)
    }

    /** How tall the answer box needs to be for this card at [backSp]. */
    private fun answerNeed(h: Hand, w: Float, backSp: Float): Float {
        val text = if (h.card.back.isNotEmpty()) h.s.linesHeight(h.card.back, w - 24f, Art.fit(h.card.back, backSp), h.s.display, 3, 1.02f) else 40f
        val hook = if (h.card.hook.isNotEmpty() && h.s.h >= 250f) 6f + h.s.linesHeight(h.card.hook, w - 24f, 12f, h.s.ui, 2) else 0f
        return text + hook + 20f
    }

    /** The answer on a soft panel: its text and picture, and (when there is room) the hook that helps remember it. */
    private fun answerBox(h: Hand, x: Float, y: Float, w: Float, bh: Float, backSp: Float, hook: Boolean, center: Boolean) {
        val s = h.s
        val card = h.card
        s.rect(s.ink(Shade.SOFT), x, y, w, bh, s.look.inner(12f))
        var tx = x + 12f
        var tw = w - 24f
        val backPicture = card.backImg?.let { Art.picture(s.ctx, it, 300) }
        if (backPicture != null) {
            val ph = bh - 16f
            val pw = min(tw * 0.45f, ph * backPicture.width / backPicture.height)
            s.picture(backPicture, tx, y + 8f, pw, ph, center = false)
            tx += pw + 10f
            tw -= pw + 10f
        }
        val showHook = hook && card.hook.isNotEmpty()
        val hookH = if (showHook) s.linesHeight(card.hook, tw, 12f, s.ui, 2) else 0f
        val align = if (center) Align.CENTER else Align.START
        if (card.back.isNotEmpty()) {
            val room = bh - 12f - (if (showHook) hookH + 6f else 0f)
            s.linesMiddle(s.ink(), card.back, tx, y + 6f, tw, room, Art.fit(card.back, backSp), s.display, 3, align, 1.02f)
        }
        if (showHook) s.lines(s.ink(Shade.MUTED), card.hook, tx, y + bh - 8f - hookH, tw, 12f, s.ui, 2, align)
    }

    private fun revealButton(h: Hand, x: Float, y: Float, w: Float, bh: Float) {
        val s = h.s
        val r = s.look.inner(bh / 2f)
        s.rect(s.ink(), x, y, w, bh, r)
        s.text(s.onInk(), "Reveal", x + w / 2f, y + bh / 2f, 15f, s.uiBold, Align.CENTER, middle = true)
        s.hit(x, y, w, bh, h.reveal, "Reveal", r)
    }

    private fun grades(h: Hand, x: Float, y: Float, w: Float, bh: Float, gap: Float, sp: Float) {
        val s = h.s
        val bw = (w - gap) / 2f
        val r = s.look.inner(bh / 2f)
        s.rect(s.col(Hue.AGAIN), x, y, bw, bh, r)
        s.text(s.col(Hue.GRAPHITE), "Again", x + bw / 2f, y + bh / 2f, sp, s.uiBold, Align.CENTER, middle = true)
        s.hit(x, y, bw, bh, h.again, "Again", r)
        s.rect(s.col(Hue.GOOD), x + bw + gap, y, bw, bh, r)
        s.text(s.col(Hue.GRAPHITE), "Got it", x + bw + gap + bw / 2f, y + bh / 2f, sp, s.uiBold, Align.CENTER, middle = true)
        s.hit(x + bw + gap, y, bw, bh, h.good, "Got it", r)
    }

    // ---------------------------------------------------------------------------------------------- answers

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != REVEAL && action != AGAIN && action != GOOD) return super.onReceive(context, intent)
        val prefs = HomeWidgetPlugin.getData(context)
        val state = WidgetState.from(prefs)
        val card = state.queue.firstOrNull()
        val cardId = intent.getStringExtra(EXTRA_CARD)
        // A tap on a card that has already moved on (a double tap, or the app refreshed the queue) does nothing.
        if (card != null && card.id == cardId) {
            val now = System.currentTimeMillis()
            if (action == REVEAL) {
                prefs.edit().putString(Keys.OPEN, card.id).putString(Keys.OPEN_AT, "$now").commit()
            } else {
                val verify = state.openAt?.takeIf { state.openCard == card.id }?.let { now - it }?.takeIf { it in 1..600_000 }
                WidgetState.record(prefs, Review(card.id, card.deck, if (action == AGAIN) 1 else 3, now, verify))
                Widgets.refreshAll(context, except = QuickCardWidget::class.java)
            }
        }
        val manager = AppWidgetManager.getInstance(context)
        onUpdate(context, manager, manager.getAppWidgetIds(ComponentName(context, QuickCardWidget::class.java)), prefs)
    }

    internal companion object {
        const val REVEAL = "com.memorycard.widget.REVEAL"
        const val AGAIN = "com.memorycard.widget.AGAIN"
        const val GOOD = "com.memorycard.widget.GOOD"
        const val EXTRA_CARD = "card"

        fun action(ctx: Context, action: String, cardId: String, widgetId: Int): PendingIntent {
            val intent = Intent(ctx, QuickCardWidget::class.java)
                .setAction(action)
                .setData(Uri.parse("memorycard://quick/$widgetId/$action/${Uri.encode(cardId)}"))
                .putExtra(EXTRA_CARD, cardId)
            return PendingIntent.getBroadcast(ctx, widgetId, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
    }
}
