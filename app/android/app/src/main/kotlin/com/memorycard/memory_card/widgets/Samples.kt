package com.memorycard.memory_card.widgets

import org.json.JSONArray
import org.json.JSONObject

/**
 * A made-up day for previews and the widget picker: goal 20, 12 done, a 14-day streak, a German deck. It has the
 * shape of the snapshot the app writes (lib/data/widget_snapshot.dart), so every widget draws from it unchanged.
 */
internal object Samples {
    fun state(
        done: Int = 12,
        streak: Int = 14,
        look: JSONObject? = null,
        turned: Boolean = false,
        empty: Boolean = false,
        memberBack: Boolean = false,
        /** Cards answered on the Quick card that the app has not seen yet (the widget moves on to the next one). */
        answered: List<String> = emptyList(),
    ): WidgetState {
        val now = System.currentTimeMillis()
        val day = dayNumber(now)
        val goal = 20
        val snap = JSONObject()
            .put("v", 2)
            .put("at", now)
            .put("offset", 0)
            .put("day", day)
            .put("goal", goal)
            .put("done", done)
            .put("goalHit", done >= goal)
            .put("mins", 9)
            .put("lastDeck", "German · A1 Basics")
            .put("lastDeckId", "de-a1")
            .put("streak", streak)
            .put("rawStreak", streak)
            .put("lastGoalDay", day - 1)
            .put("shields", 1)
            .put("best", 21)
            .put("goalDays", JSONArray(listOf(day - 6, day - 5, day - 3, day - 2, day - 1)))
            .put("health", 0.86)
            .put("slipping", 6)
            .put("tomorrow", 11)
            .put("queue", if (empty) JSONArray() else queue())
        if (look != null) snap.put("look", look)
        WidgetSamples.extend(snap, day)
        val open = if (turned) "c1" else null
        val inbox = answered.map { Review(it, "de-a1", 3, now - 60_000, null) }
        return WidgetState(snap, inbox, 0L, open, if (turned) now - 4000 else null, now, memberBack)
    }

    /** A phone that has never heard from the app: no snapshot at all (widgets just placed, before the app first runs). */
    fun blank(): WidgetState = WidgetState(null, emptyList(), 0L, null, null)

    private fun queue(): JSONArray {
        fun card(id: String, deck: String, deckName: String, front: String, back: String, label: String, example: String, hook: String, r: Double) =
            JSONObject().put("id", id).put("deck", deck).put("deckName", deckName).put("front", front).put("back", back)
                .put("label", label).put("example", example).put("hook", hook).put("r", r)
        return JSONArray()
            .put(card("c1", "de-a1", "German · A1 Basics", "der Apfel", "the apple", "noun · masculine", "Ich esse jeden Tag einen Apfel.", "Apfel is masculine: der Apfel, die Äpfel", 0.71))
            .put(card("c2", "de-a1", "German · A1 Basics", "das Wasser", "the water", "noun · neuter", "Ein Glas Wasser, bitte.", "", 0.78))
            .put(card("c3", "es-b", "Spanish · Basics", "la manzana", "the apple", "noun · feminine", "", "", 0.83))
    }
}
