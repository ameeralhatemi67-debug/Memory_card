package com.memorycard.memory_card.widgets

import android.content.Context
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import com.memorycard.memory_card.R

/** Daily goal seal: today's cards against the goal; the red DONE seal once it is met. Tap: study the last deck. */
class SealWidget : McWidget() {
    override val sizes = listOf(SizeF(40f, 40f), SizeF(110f, 40f), SizeF(110f, 150f))

    override fun build(ctx: Context, size: Int, state: WidgetState, widgetId: Int): RemoteViews {
        val v = RemoteViews(ctx.packageName, intArrayOf(R.layout.wg_seal_s, R.layout.wg_seal_m, R.layout.wg_seal_l)[size])
        val sealDp = floatArrayOf(36f, 64f, 92f)[size]
        val hit = state.goalHit
        val pressed = if (hit) View.VISIBLE else View.GONE
        val filling = if (hit) View.GONE else View.VISIBLE
        for (id in intArrayOf(R.id.seal_base, R.id.seal_track, R.id.seal_arc, R.id.seal_text)) v.setViewVisibility(id, filling)
        v.setViewVisibility(R.id.seal_done, pressed)
        v.setViewVisibility(R.id.seal_done_text, if (hit && size > 0) View.VISIBLE else View.GONE)

        if (hit) {
            if (size > 0) v.setImageViewBitmap(R.id.seal_done_text, Art.doneStamp(ctx, sealDp))
        } else {
            v.setImageViewBitmap(R.id.seal_arc, Art.arc(ctx, sealDp, state.done.toFloat() / state.goal))
            if (size > 0) {
                v.setImageViewBitmap(R.id.seal_text, Art.text(ctx, "${state.done}/${state.goal}", if (size == 1) 15f else 22f, sealDp * 0.6f))
            } else {
                v.setViewVisibility(R.id.seal_text, View.GONE)
            }
        }

        val big = when {
            size == 2 && hit -> "Goal met"
            size == 2 -> "${state.left} to go"
            hit -> "Done"
            else -> "${state.left}"
        }
        v.setImageViewBitmap(R.id.big, Art.text(ctx, big, floatArrayOf(20f, 30f, 26f)[size], if (size == 2) 106f else 80f, center = true))
        v.setContentDescription(R.id.big, if (hit) "Goal reached: ${state.done} cards today" else "${state.left} of ${state.goal} cards to go today")

        val sub = when {
            !state.ready -> if (size == 2) "Open Memory Card once to start" else "to go"
            size < 2 -> if (hit) "goal met" else "to go"
            hit -> "Anything more is a bonus"
            else -> listOfNotNull(state.lastDeck, if (state.minutes > 0) "${state.minutes} min" else null)
                .joinToString(" · ").ifEmpty { "of ${state.goal} today" }
        }
        v.setTextViewText(R.id.sub, sub)
        v.setOnClickPendingIntent(R.id.root, open(ctx, "memorycard://study"))
        return v
    }
}
