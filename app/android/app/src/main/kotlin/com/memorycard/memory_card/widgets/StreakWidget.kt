package com.memorycard.memory_card.widgets

import android.content.Context
import android.util.SizeF
import android.widget.RemoteViews
import com.memorycard.memory_card.R

/** Streak flame: the streak and this month's grace shields. After 18:00 with the goal not met, it asks for today. */
class StreakWidget : McWidget() {
    override val sizes = listOf(SizeF(40f, 40f), SizeF(110f, 40f), SizeF(230f, 40f))

    override fun build(ctx: Context, size: Int, state: WidgetState, widgetId: Int): RemoteViews {
        val v = RemoteViews(ctx.packageName, intArrayOf(R.layout.wg_streak_s, R.layout.wg_streak_m, R.layout.wg_streak_l)[size])
        val n = state.streak
        val waiting = state.atRisk || n == 0
        v.setImageViewResource(R.id.flame, if (waiting) R.drawable.wg_flame_outline else R.drawable.wg_flame)

        val big = when {
            size < 2 -> "$n"
            n == 0 -> "No streak yet"
            else -> "$n-day streak"
        }
        v.setImageViewBitmap(R.id.big, Art.text(ctx, big, floatArrayOf(24f, 36f, 26f)[size], if (size == 2) 170f else 80f))
        v.setContentDescription(R.id.big, "$n-day streak, ${state.shields} grace shields left")

        val sub = when (size) {
            0 -> "days"
            1 -> when {
                n == 0 -> "start today"
                state.atRisk -> "study today"
                else -> "day streak"
            }
            else -> when {
                n == 0 -> "Reach today's goal to start one"
                state.atRisk -> "Study today to keep it"
                else -> "${state.shields} grace ${if (state.shields == 1) "shield" else "shields"} left this month"
            }
        }
        v.setTextViewText(R.id.sub, sub)

        if (size > 0) {
            v.setImageViewResource(R.id.shield1, if (state.shields >= 1) R.drawable.wg_shield else R.drawable.wg_shield_outline)
            v.setImageViewResource(R.id.shield2, if (state.shields >= 2) R.drawable.wg_shield else R.drawable.wg_shield_outline)
        }
        v.setOnClickPendingIntent(R.id.root, open(ctx, "memorycard://today"))
        return v
    }
}
