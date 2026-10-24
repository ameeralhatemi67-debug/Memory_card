package com.memorycard.memory_card.widgets

import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min

// What the newer widgets read from the snapshot (lib/data/widget_snapshot.dart), brought up to the present.

private const val TWO_HOURS = 2 * 3_600_000L

internal val WidgetState.mastered: Int get() = snap?.optInt("mastered") ?: 0
internal val WidgetState.totalSwipes: Int get() = (snap?.optInt("total") ?: 0) + pending.size

/** The library's mean predicted recall right now (0–1), or null before anything has been learned. */
internal val WidgetState.health: Double?
    get() {
        val series = snap?.optJSONArray("hz") ?: return snap?.takeIf { !it.isNull("health") }?.optDouble("health")
        if (series.length() == 0) return null
        return interpolate { series.optDouble(it) }
    }

/** Cards slipping right now (below 90 % predicted recall). */
internal val WidgetState.slippingNow: Int
    get() {
        val series = snap?.optJSONArray("sz") ?: return snap?.optInt("slipping") ?: 0
        if (series.length() == 0) return 0
        return interpolate { series.optDouble(it) }.toInt()
    }

/** Recall only falls while you are away: the app writes a value every two hours, and the widget steps along them. */
private fun WidgetState.interpolate(at: (Int) -> Double): Double {
    val n = snap?.optJSONArray("hz")?.length() ?: 1
    val since = (clock - (snap?.optLong("at") ?: clock)).coerceAtLeast(0L)
    val f = (since.toDouble() / TWO_HOURS).coerceAtMost((n - 1).toDouble())
    val i = f.toInt()
    val a = at(i)
    val b = at(min(n - 1, i + 1))
    return a + (b - a) * (f - i)
}

/** Swipes per study day, oldest first, today last (answers given on the Quick card count). */
internal val WidgetState.heat: List<Int>
    get() {
        val raw = (snap?.ints("heat") ?: emptyList()).toMutableList()
        if (raw.isEmpty()) return List(126) { 0 }
        // A new study day since the snapshot: slide the days along.
        val shift = (today - snapDay).toInt().coerceIn(0, raw.size)
        repeat(shift) {
            raw.removeAt(0)
            raw.add(0)
        }
        raw[raw.size - 1] = raw[raw.size - 1] + (if (sameDay) reviewedHere else 0)
        return raw
    }

/** Cards that start slipping on each of the next 14 days; today's count includes those already slipping. */
internal val WidgetState.forecast: List<Int>
    get() {
        val raw = snap?.ints("forecast") ?: emptyList()
        if (raw.isEmpty()) return List(14) { 0 }
        val shift = (today - snapDay).toInt().coerceIn(0, raw.size - 1)
        if (shift == 0) return raw
        val out = MutableList(raw.size) { 0 }
        out[0] = raw.take(shift + 1).sum()
        for (i in 1 until raw.size) out[i] = raw.getOrElse(shift + i) { 0 }
        return out
    }

internal class Member(o: JSONObject?) {
    val tier = o?.optString("tier", "Bronze") ?: "Bronze"
    val name = o?.optString("name", "Guest Learner") ?: "Guest Learner"
    val since = o?.optInt("since", 2026) ?: 2026
    val felt: Double? = if (o == null || o.isNull("felt")) null else o.optDouble("felt")
}

internal val WidgetState.member: Member get() = Member(snap?.optJSONObject("member"))

internal class SealMark(o: JSONObject) {
    val mark = o.optString("mark")
    val title = o.optString("title")

    /** 0 red · 1 blue · 2 peach · 3 green · 4 ink (lib/engine/seals.dart). */
    val color = o.optInt("color")
}

internal class NextSeal(o: JSONObject) {
    val mark = o.optString("mark")
    val title = o.optString("title")
    val color = o.optInt("color")
    val have = o.optDouble("have")
    val need = o.optDouble("need")
    val unit = o.optString("unit")
    val fraction get() = (have / max(1.0, need)).coerceIn(0.0, 1.0).toFloat()
    val left get() = (need - have).toInt().coerceAtLeast(0)
}

internal class SealsInfo(o: JSONObject?) {
    val earned = o?.optInt("earned") ?: 0
    val total = o?.optInt("total") ?: 20
    val latest: List<SealMark> = o?.optJSONArray("latest")?.let { a -> (0 until a.length()).mapNotNull { a.optJSONObject(it)?.let(::SealMark) } } ?: emptyList()
    val next: NextSeal? = o?.optJSONObject("next")?.let(::NextSeal)
}

internal val WidgetState.seals: SealsInfo get() = SealsInfo(snap?.optJSONObject("seals"))

internal class DeckInfo(o: JSONObject) {
    val id = o.optString("id")
    val name = o.optString("name")
    val cards = o.optInt("cards")
    val slipping = o.optInt("slipping")
    val fresh = o.optInt("fresh")
    val steps = o.optInt("steps")
}

internal val WidgetState.decks: List<DeckInfo>
    get() = snap?.optJSONArray("decks")?.let { a -> (0 until a.length()).mapNotNull { a.optJSONObject(it)?.let(::DeckInfo) } } ?: emptyList()

/** Slipping cards across every deck, and in how many decks. */
internal val WidgetState.mixSlipping: Int get() = snap?.optJSONObject("mix")?.optInt("slipping") ?: 0
internal val WidgetState.mixDecks: Int get() = snap?.optJSONObject("mix")?.optInt("decks") ?: 0

/** A mastered card for "Card of the day". */
internal class DayCard(o: JSONObject) {
    val id = o.optString("id")
    val deck = o.optString("deck")
    val deckName = o.optString("deckName")
    val front = o.optString("front")
    val back = o.optString("back")
    val label = o.optString("label")
    val hook = o.optString("hook")
    val recall = o.optDouble("r", 1.0)
    val mono = o.optBoolean("mono")
}

/** The card of the day for this stretch of the day: the list turns over every four hours. */
internal val WidgetState.cardOfTheDay: DayCard?
    get() {
        val a = snap?.optJSONArray("cotd") ?: return null
        if (a.length() == 0) return null
        val slot = (clock / (4 * 3_600_000L) + today).toInt()
        return a.optJSONObject(Math.floorMod(slot, a.length()))?.let(::DayCard)
    }
