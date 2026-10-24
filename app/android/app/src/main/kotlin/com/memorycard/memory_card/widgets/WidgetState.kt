package com.memorycard.memory_card.widgets

import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.max

/** Keys shared with lib/data/widget_snapshot.dart (WidgetKeys). */
internal object Keys {
    const val SNAPSHOT = "mc.snapshot"
    const val INBOX = "mc.inbox"
    const val APPLIED = "mc.inbox.applied"

    /** The Quick card that is turned over, and when it was. */
    const val OPEN = "mc.qc.open"
    const val OPEN_AT = "mc.qc.openAt"

    /** The membership card is showing its back. */
    const val MEMBER_BACK = "mc.member.back"
}

/** Study days start at 04:00 local time, as in lib/engine/days.dart. */
internal fun dayNumber(ms: Long): Long =
    Instant.ofEpochMilli(ms).atZone(ZoneId.systemDefault()).minusHours(4).toLocalDate().toEpochDay()

/** Monday is 0. */
internal fun weekdayOf(day: Long): Int = LocalDate.ofEpochDay(day).dayOfWeek.value - 1

internal fun JSONObject.text(key: String): String? = if (isNull(key)) null else optString(key).ifEmpty { null }

internal fun JSONObject.ints(key: String): List<Int> {
    val a = optJSONArray(key) ?: return emptyList()
    return List(a.length()) { a.optInt(it) }
}

/** A card the Quick card can show (lib/data/widget_snapshot.dart › widgetQueue). */
internal class QCard(o: JSONObject) {
    val id = o.optString("id")
    val deck = o.optString("deck")
    val deckName = o.optString("deckName")
    val front = o.optString("front")
    val back = o.optString("back")
    val label = o.optString("label")
    val example = o.optString("example")
    val hook = o.optString("hook")
    val recall = o.optDouble("r", 1.0)
    val mono = o.optBoolean("mono")
    val img = o.text("img")

    /** "blur" or "hide" while the front picture waits for the reveal. */
    val imgReveal = o.text("imgReveal")
    val backImg = o.text("backImg")
    val slipping get() = recall < 0.9
}

/** One answer given on the Quick card, waiting for the app (lib/data/widget_snapshot.dart › WidgetReview). */
internal class Review(val card: String, val deck: String, val grade: Int, val ts: Long, val verify: Long?) {
    fun toJson(): JSONObject = JSONObject().put("card", card).put("deck", deck).put("grade", grade).put("ts", ts).apply {
        if (verify != null) put("verify", verify)
    }

    companion object {
        fun from(o: JSONObject?): Review? {
            if (o == null || !o.has("card") || !o.has("ts")) return null
            return Review(o.optString("card"), o.optString("deck"), o.optInt("grade", 3), o.optLong("ts"),
                if (o.has("verify")) o.optLong("verify") else null)
        }
    }
}

/**
 * What every widget draws: the app's last snapshot, brought up to the present. Answers given on the Quick card
 * since then are counted in, and a study day the app has not seen yet is worked out the way the engine would
 * (a new day starts empty; missed days use grace shields or end the streak).
 */
internal class WidgetState(
    /** The app's snapshot, as written (null until the app has run once). */
    val snap: JSONObject?,
    inbox: List<Review>,
    applied: Long,
    val openCard: String?,
    val openAt: Long?,
    /** The phone's real clock, in ms. */
    val clock: Long = System.currentTimeMillis(),
    /** The membership card has been turned over. */
    val memberBack: Boolean = false,
) {
    /** The app has written a snapshot (it has been opened since the widget was placed). */
    val ready = snap != null
    val look = Look(snap?.optJSONObject("look"))
    val offset = snap?.optLong("offset") ?: 0L
    val now = clock + offset
    val today = dayNumber(now)
    val snapDay = snap?.optLong("day", today) ?: today
    val sameDay = snapDay == today

    val pending: List<Review> = inbox.filter { it.ts > applied }
    private val answeredToday = pending.filter { dayNumber(it.ts + offset) == today }

    /** Quick card answers given today that the app has not counted yet. */
    val reviewedHere = answeredToday.size

    val goal = snap?.optInt("goal", 20) ?: 20
    val done = (if (sameDay) snap?.optInt("done") ?: 0 else 0) + reviewedHere
    private val snapGoalHit = snap?.optBoolean("goalHit") == true
    val goalHit = (sameDay && snapGoalHit) || done >= goal
    val left = max(0, goal - done)
    val lastDeck = snap?.text("lastDeck")
    val minutes = if (sameDay) snap?.optInt("mins") ?: 0 else 0
    val best = snap?.optInt("best") ?: 0

    /** How today's answers went: remembered, relearned (Again), and the Hard and Easy among the remembered. */
    val ok = (if (sameDay) snap?.optInt("ok") ?: 0 else 0) + answeredToday.count { it.grade >= 3 }
    val fail = (if (sameDay) snap?.optInt("fail") ?: 0 else 0) + answeredToday.count { it.grade <= 1 }
    val hard = if (sameDay) snap?.optInt("hard") ?: 0 else 0
    val easy = if (sameDay) snap?.optInt("easy") ?: 0 else 0
    val good get() = max(0, ok - hard - easy)

    val streak: Int
    val shields: Int

    init {
        val raw = snap?.optInt("rawStreak") ?: 0
        val lastGoal = snap?.optLong("lastGoalDay", -100000L) ?: -100000L
        var sh = snap?.optInt("shields", 2) ?: 2
        if (sameDay) {
            streak = if (snapGoalHit || done < goal) snap?.optInt("streak") ?: 0 else grown(raw, today - lastGoal)
        } else {
            var s = raw
            var last = lastGoal
            if (s > 0) {
                var d = last + 1
                while (d < today) {
                    if (sh > 0) {
                        sh--
                        last = d
                    } else {
                        s = 0
                        break
                    }
                    d++
                }
            }
            streak = if (done >= goal) grown(s, today - last) else if (today - last <= 1) s else 0
        }
        shields = sh
    }

    /** The streak once today's goal is met, [gap] days after the last goal day (StudyEngine.swipe). */
    private fun grown(streak: Int, gap: Long) = when (gap) {
        1L -> streak + 1
        0L -> streak
        else -> 1
    }

    /** After 18:00 with the goal not met yet, the flame asks for today. */
    val atRisk = !goalHit && streak > 0 && Instant.ofEpochMilli(now).atZone(ZoneId.systemDefault()).hour >= 18

    /** Study days of the last two weeks on which the goal was met (not counting today). */
    val goalDays: Set<Long> = snap?.optJSONArray("goalDays")?.let { a -> (0 until a.length()).map { a.optLong(it) }.toSet() } ?: emptySet()

    /** The same day drawn with another Look (Settings shows the choices as they are made). */
    fun withLook(look: JSONObject): WidgetState {
        val copy = JSONObject(snap?.toString() ?: "{}").put("look", look)
        return WidgetState(copy, pending, 0L, openCard, openAt, clock, memberBack)
    }

    /** The Quick card's cards, minus the ones answered here since the snapshot. */
    val queue: List<QCard> = run {
        val answered = pending.map { it.card }.toSet()
        val list = snap?.optJSONArray("queue") ?: JSONArray()
        (0 until list.length()).mapNotNull { list.optJSONObject(it)?.let(::QCard) }.filter { it.id !in answered }
    }
    val slippingLeft = queue.count { it.slipping }

    companion object {
        fun from(prefs: SharedPreferences): WidgetState = WidgetState(
            snap = prefs.getString(Keys.SNAPSHOT, null)?.let { runCatching { JSONObject(it) }.getOrNull() },
            inbox = readInbox(prefs),
            applied = prefs.getString(Keys.APPLIED, null)?.toLongOrNull() ?: 0L,
            openCard = prefs.getString(Keys.OPEN, null),
            openAt = prefs.getString(Keys.OPEN_AT, null)?.toLongOrNull(),
            memberBack = prefs.getBoolean(Keys.MEMBER_BACK, false),
        )

        fun readInbox(prefs: SharedPreferences): List<Review> {
            val raw = prefs.getString(Keys.INBOX, null) ?: return emptyList()
            val list = runCatching { JSONArray(raw) }.getOrNull() ?: return emptyList()
            return (0 until list.length()).mapNotNull { Review.from(list.optJSONObject(it)) }
        }

        /** Adds an answer to the inbox (dropping the ones the app has applied) and turns the card back over. */
        fun record(prefs: SharedPreferences, review: Review) {
            val applied = prefs.getString(Keys.APPLIED, null)?.toLongOrNull() ?: 0L
            val list = JSONArray()
            for (r in readInbox(prefs)) if (r.ts > applied) list.put(r.toJson())
            list.put(review.toJson())
            prefs.edit().putString(Keys.INBOX, list.toString()).remove(Keys.OPEN).remove(Keys.OPEN_AT).commit()
        }
    }
}
