package com.memorycard.memory_card.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.SizeF
import es.antonborri.home_widget.HomeWidgetPlugin
import com.memorycard.memory_card.R
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** The fixed colour of a seal's fill: 0 red (your accent) · 1 blue · 2 peach · 3 green · 4 ink (the face's own ink). */
internal fun sealFill(s: Scene, color: Int): Pair<Int, Int> = when (color) {
    0 -> s.look.accent to s.look.accent
    1 -> Hue.BLUE to Hue.BLUE
    2 -> Hue.PEACH to Hue.PEACH
    3 -> Hue.GOOD to Hue.GOOD
    else -> s.faceTones().second
}

/** The lettering on a seal: paper white on red, graphite on the light fills, the face's colour on the ink one. */
internal fun sealInk(s: Scene, color: Int): Brush = when (color) {
    0 -> s.col(Hue.PAPER)
    4 -> s.onInk()
    else -> s.col(Hue.GRAPHITE)
}

/**
 * One earned seal at [cx],[cy]: its slowly turning wax, a pressed ring and its mark. [moving] false draws the wax on
 * the page instead, for a face that turns over (a moving piece does not turn with the page).
 */
internal fun sealDisc(s: Scene, mark: SealMark, cx: Float, cy: Float, size: Float, markSize: Float, moving: Boolean = true) {
    val (day, night) = sealFill(s, mark.color)
    val wax = { s.seal(if (mark.color == 4) s.ink() else s.col(day), cx, cy, size) }
    if (moving) s.sprite(Fx.SEAL, cx - size / 2f, cy - size / 2f, size, size, day, night) { wax() } else wax()
    s.ring(s.col(0x80FFFFFF.toInt()), cx, cy, size * 0.33f, size * 0.02f)
    s.text(sealInk(s, mark.color), mark.mark, cx, cy, markSize, s.display, Align.CENTER, maxW = size * 0.62f, middle = true)
}

/**
 * Membership card: your tier, name and four numbers, drawn like the card in Profile. Tap it to turn it over: the back
 * has your last five weeks, streak and shields. A strip of your latest seals runs along the bottom (tap: all seals).
 * A band of light crosses the card every few seconds. Everything on the card is drawn on it (the flame and the seals
 * do not move) so the whole card turns over as one.
 */
class MembershipWidget : SceneWidget() {
    override val kind = "membership"
    override val natural = Surface.INK
    override val turns = true
    override val swaps = true
    override val cells = listOf(4 to 2)

    override fun draw(s: Scene, st: WidgetState, id: Int) {
        val m = st.member
        s.description = "${m.tier} tier membership card for ${m.name}. ${st.mastered} mastered, ${st.streak}-day streak. Tap to turn it over."
        val strip = 38f
        val cardH = s.h - strip - 6f
        if (st.memberBack) back(s, st, m, cardH) else front(s, st, m, cardH)
        // Tap the card to turn it; the strip opens the seals.
        s.hit(0f, 0f, s.w, cardH, flipIntent(s.ctx, id), "Turn the card over", s.look.radius, ripple = false)
        seals(s, st, strip)
        val (lightDay, lightNight) = s.glint()
        s.sprite(Fx.SHEEN, 0f, 0f, s.w, cardH, lightDay, lightNight) { }
    }

    private fun tierColor(tier: String) = when (tier) {
        "Platinum" -> 0xFFBFE3EC.toInt()
        "Gold" -> 0xFFE9C46A.toInt()
        "Silver" -> Hue.SILVER
        else -> 0xFFD9A273.toInt()
    }

    private fun front(s: Scene, st: WidgetState, m: Member, cardH: Float) {
        val pad = 18f
        val label = "${m.tier.uppercase()} TIER"
        val pw = s.measure(label, 11f, s.uiBold, 1f) + 20f
        s.pill(s.col(tierColor(m.tier)), pad, pad, pw, 22f)
        s.text(s.col(Hue.GRAPHITE), label, pad + pw / 2f, pad + 11f, 11f, s.uiBold, Align.CENTER, spacing = 1f, middle = true)
        s.vec(s.ink(), R.drawable.wg_logo, s.w - pad - 24f, pad - 3f, 24f, 31f)
        s.text(s.ink(), m.name, pad, cardH * 0.5f, 28f, s.display, maxW = s.w - pad * 2)
        // Four numbers along the bottom of the card.
        val digits = listOf(
            "%04d".format(st.mastered.coerceIn(0, 9999)) to "mastered",
            "%04d".format(st.streak.coerceIn(0, 9999)) to "streak",
            (st.health?.let { "%04d".format((it * 100).roundToInt()) } ?: "----") to "health %",
            "${m.since}" to "since",
        )
        val col = (s.w - pad * 2) / 4f
        val labelY = cardH - 10f
        for ((i, d) in digits.withIndex()) {
            val x = pad + i * col
            s.text(s.ink(0.54f), d.first, x, labelY - 15f, 23f, s.display, spacing = 1f, maxW = col - 4f)
            s.text(s.ink(Shade.MUTED), d.second.uppercase(), x, labelY, 9.5f, s.uiBold, spacing = 1f, maxW = col - 4f)
        }
    }

    private fun back(s: Scene, st: WidgetState, m: Member, cardH: Float) {
        // The magnetic stripe.
        s.rect(s.col(0x59000000), 0f, 14f, s.w, 26f)
        val pad = 16f
        s.text(s.ink(Shade.MUTED), "LAST 5 WEEKS", pad, 60f, 9.5f, s.uiBold, spacing = 1f)
        val cell = 11f
        val gap = 3f
        val days = st.heat
        for (i in 0 until 35) {
            val x = pad + (i % 7) * (cell + gap)
            val y = 68f + (i / 7) * (cell + gap)
            s.rect(s.ink(HEAT_LEVELS[heatLevel(days[days.size - 35 + i])]), x, y, cell, cell, 3f)
            if (i == 34) s.outline(s.accent, x, y, cell, cell, 3f, 1.5f)
        }
        val x = pad + 7 * (cell + gap) + 18f
        val rw = s.w - x - pad
        flameMark(s, st, x, 56f, 15f, 18f, still = true)
        s.text(s.ink(), if (st.streak == 0) "No streak yet" else "${st.streak}-day streak", x + 22f, 72f, 20f, s.display, maxW = rw - 22f)
        shieldRow(s, st, x, 82f, 11f, 13f, 3f)
        s.text(s.ink(Shade.MUTED), "${st.shields} ${if (st.shields == 1) "shield" else "shields"} left", x + 30f, 93f, 11.5f, s.uiBold, maxW = rw - 30f)
        s.text(s.ink(Shade.MUTED), "${st.mastered} mastered · ${st.health?.let { "${(it * 100).roundToInt()}%" } ?: "—"} health", x, 114f, 11.5f, s.uiBold, maxW = rw)
        m.felt?.let { s.text(s.ink(Shade.MUTED), "${(it * 100).roundToInt()}% felt success", x, 130f, 11.5f, s.uiBold, maxW = rw) }
        s.text(s.ink(Shade.MUTED), "Member since ${m.since} · best streak ${st.best}", s.w - pad, cardH - 8f, 10f, s.uiBold, Align.END, maxW = s.w - pad * 2)
    }

    /** The latest seals, each turning, with their count. */
    private fun seals(s: Scene, st: WidgetState, strip: Float) {
        val info = st.seals
        val y = s.h - strip - 4f
        val r = s.look.inner(14f)
        s.rect(s.ink(0.1f), 8f, y, s.w - 16f, strip, r)
        s.hit(8f, y, s.w - 16f, strip, SceneWidget.open(s.ctx, "memorycard://seals"), "All seals", r)
        val disc = 26f
        var x = 20f
        for (m in info.latest.take(4)) {
            sealDisc(s, m, x + disc / 2f, y + strip / 2f, disc, 7.5f, moving = false)
            x += disc + 6f
        }
        s.text(s.ink(), "Seals · ${info.earned} of ${info.total}", max(x + 6f, 20f), y + strip / 2f, 13f, s.uiBold, middle = true, maxW = s.w - x - 24f)
    }

    // ---------------------------------------------------------------------------------------------- turning the card

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != FLIP) return super.onReceive(context, intent)
        val prefs = HomeWidgetPlugin.getData(context)
        prefs.edit().putBoolean(Keys.MEMBER_BACK, !prefs.getBoolean(Keys.MEMBER_BACK, false)).commit()
        val manager = AppWidgetManager.getInstance(context)
        onUpdate(context, manager, manager.getAppWidgetIds(ComponentName(context, MembershipWidget::class.java)), prefs)
    }

    private fun flipIntent(ctx: Context, id: Int): PendingIntent {
        val intent = Intent(ctx, MembershipWidget::class.java).setAction(FLIP).setData(Uri.parse("memorycard://member/flip/$id"))
        return PendingIntent.getBroadcast(ctx, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private companion object {
        const val FLIP = "com.memorycard.widget.FLIP"
        val HEAT_LEVELS = floatArrayOf(0.11f, 0.27f, 0.5f, 0.74f, 1f)
    }
}
