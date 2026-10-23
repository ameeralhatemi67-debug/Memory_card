package com.memorycard.memory_card.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import com.memorycard.memory_card.R
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Quick card: the card you are closest to forgetting, right on the home screen. Reveal turns it over; Again or
 * Got it records the answer in the inbox and brings the next card. The app replays the answers through the
 * engine the next time it opens (AppStore.applyWidgetReviews), so nothing here needs Dart to run.
 */
class QuickCardWidget : McWidget() {
    override val sizes = listOf(SizeF(110f, 110f), SizeF(230f, 140f), SizeF(230f, 260f))

    private class Spec(
        val layout: Int,
        val header: Boolean,
        val example: Boolean,
        val hiddenBox: Boolean,
        val hook: Boolean,
        val frontSp: Float,
        val frontDp: Float,
        val frontLines: Int,
        val center: Boolean,
        val backSp: Float,
        val backDp: Float,
        val picturePx: Int,
        val turnedSp: Float,
    )

    private val specs = listOf(
        Spec(R.layout.wg_quick_m, false, false, false, false, 28f, 106f, 3, true, 20f, 90f, 260, 15f),
        Spec(R.layout.wg_quick_l, true, true, false, false, 32f, 240f, 2, false, 22f, 200f, 320, 17f),
        Spec(R.layout.wg_quick_xl, true, true, true, true, 36f, 220f, 2, true, 24f, 220f, 360, 26f),
    )

    override fun build(ctx: Context, size: Int, state: WidgetState, widgetId: Int): RemoteViews {
        val spec = specs[size]
        val v = RemoteViews(ctx.packageName, spec.layout)
        val card = state.queue.firstOrNull()
        if (!state.ready || card == null) return empty(ctx, v, state)

        v.setViewVisibility(R.id.q_content, View.VISIBLE)
        v.setViewVisibility(R.id.q_empty, View.GONE)
        val turned = state.openCard == card.id

        v.setViewVisibility(R.id.q_header, if (spec.header) View.VISIBLE else View.GONE)
        if (spec.header) {
            v.setTextViewText(R.id.q_deck, card.deckName)
            val left = state.slippingLeft
            v.setTextViewText(R.id.q_count, when {
                state.reviewedHere > 0 && left > 0 -> "${state.reviewedHere} done · $left left"
                state.reviewedHere > 0 -> "${state.reviewedHere} done"
                left > 0 -> "$left slipping"
                else -> "Review ahead"
            })
            v.setOnClickPendingIntent(R.id.q_header, open(ctx, "memorycard://study?deck=${Uri.encode(card.deck)}"))
        }

        // Turned over, the answer needs the room the label had.
        v.setTextViewText(R.id.q_label, card.label)
        v.setViewVisibility(R.id.q_label, if (card.label.isEmpty() || (turned && size < 2)) View.GONE else View.VISIBLE)

        // The prompt: its picture (blurred or hidden until the reveal when the card asks for it), else its text.
        val waits = !turned && card.imgReveal != null
        val picture = card.img?.takeUnless { waits && card.imgReveal == "hide" }
            ?.let { Art.picture(ctx, it, spec.picturePx, blur = waits) }
        if (picture != null) {
            v.setImageViewBitmap(R.id.q_front_img, picture)
            v.setContentDescription(R.id.q_front_img, card.front.ifEmpty { "Picture" })
            v.setViewVisibility(R.id.q_front_img, View.VISIBLE)
            v.setViewVisibility(R.id.q_front_text, View.GONE)
        } else {
            val prompt = card.front.ifEmpty { if (card.img != null) "Picture hidden until you reveal" else "?" }
            var sp = if (card.front.isEmpty()) 15f else Art.fit(prompt, spec.frontSp) * if (card.mono) 0.75f else 1f
            // Turned over, the answer takes the room: the prompt steps down to one line instead of being squeezed.
            if (turned) sp = minOf(sp, spec.turnedSp)
            val lines = if (turned && size < 2) 1 else spec.frontLines
            v.setImageViewBitmap(R.id.q_front_text, Art.text(ctx, prompt, sp, spec.frontDp, lines, spec.center, card.mono))
            v.setContentDescription(R.id.q_front_text, prompt)
            v.setViewVisibility(R.id.q_front_text, View.VISIBLE)
            v.setViewVisibility(R.id.q_front_img, View.GONE)
        }

        val example = spec.example && !turned && card.example.isNotEmpty()
        v.setViewVisibility(R.id.q_example, if (example) View.VISIBLE else if (spec.example) View.INVISIBLE else View.GONE)
        if (example) v.setTextViewText(R.id.q_example, card.example)
        v.setViewVisibility(R.id.q_hidden, if (spec.hiddenBox && !turned) View.VISIBLE else View.GONE)

        v.setViewVisibility(R.id.q_answer, if (turned) View.VISIBLE else View.GONE)
        if (turned) {
            val backPicture = card.backImg?.let { Art.picture(ctx, it, spec.picturePx) }
            if (card.back.isNotEmpty()) {
                v.setImageViewBitmap(R.id.q_back_text, Art.text(ctx, card.back, Art.fit(card.back, spec.backSp), spec.backDp, 3, spec.center))
                v.setContentDescription(R.id.q_back_text, card.back)
                v.setViewVisibility(R.id.q_back_text, View.VISIBLE)
            } else {
                v.setViewVisibility(R.id.q_back_text, View.GONE)
            }
            if (backPicture != null) v.setImageViewBitmap(R.id.q_back_img, backPicture)
            v.setViewVisibility(R.id.q_back_img, if (backPicture != null) View.VISIBLE else View.GONE)
            val hook = spec.hook && card.hook.isNotEmpty()
            v.setViewVisibility(R.id.q_hook, if (hook) View.VISIBLE else View.GONE)
            if (hook) v.setTextViewText(R.id.q_hook, card.hook)
        }

        v.setViewVisibility(R.id.q_reveal, if (turned) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.q_grades, if (turned) View.VISIBLE else View.GONE)
        if (turned) {
            v.setOnClickPendingIntent(R.id.q_again, action(ctx, AGAIN, card.id, widgetId))
            v.setOnClickPendingIntent(R.id.q_good, action(ctx, GOOD, card.id, widgetId))
        } else {
            v.setOnClickPendingIntent(R.id.q_reveal, action(ctx, REVEAL, card.id, widgetId))
        }
        return v
    }

    private fun empty(ctx: Context, v: RemoteViews, state: WidgetState): RemoteViews {
        v.setViewVisibility(R.id.q_content, View.GONE)
        v.setViewVisibility(R.id.q_empty, View.VISIBLE)
        val title = if (state.ready) "All caught up" else "Quick card"
        v.setImageViewBitmap(R.id.q_empty_title, Art.text(ctx, title, 22f, 200f))
        v.setContentDescription(R.id.q_empty_title, title)
        v.setTextViewText(
            R.id.q_empty_sub,
            if (state.ready) "Nothing to recall here right now.\nOpen Memory Card for more." else "Open Memory Card once to start.",
        )
        v.setOnClickPendingIntent(R.id.root, open(ctx, "memorycard://study"))
        return v
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != REVEAL && action != AGAIN && action != GOOD) return super.onReceive(context, intent)
        val prefs = HomeWidgetPlugin.getData(context)
        val state = WidgetState(prefs)
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
                refresh(context, SealWidget::class.java)
                refresh(context, StreakWidget::class.java)
            }
        }
        val manager = AppWidgetManager.getInstance(context)
        onUpdate(context, manager, manager.getAppWidgetIds(ComponentName(context, QuickCardWidget::class.java)), prefs)
    }

    private fun action(ctx: Context, action: String, cardId: String, widgetId: Int): PendingIntent {
        val intent = Intent(ctx, QuickCardWidget::class.java)
            .setAction(action)
            .setData(Uri.parse("memorycard://quick/$widgetId/$action/${Uri.encode(cardId)}"))
            .putExtra(EXTRA_CARD, cardId)
        return PendingIntent.getBroadcast(ctx, widgetId, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private companion object {
        const val REVEAL = "com.memorycard.widget.REVEAL"
        const val AGAIN = "com.memorycard.widget.AGAIN"
        const val GOOD = "com.memorycard.widget.GOOD"
        const val EXTRA_CARD = "card"
    }
}
