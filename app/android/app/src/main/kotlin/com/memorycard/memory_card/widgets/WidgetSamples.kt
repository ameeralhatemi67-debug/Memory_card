package com.memorycard.memory_card.widgets

import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.floor
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin

/** The made-up numbers of the newer widgets (the Widgets canvas' sample data), added to the sample snapshot. */
internal object WidgetSamples {
    fun extend(snap: JSONObject, day: Long) {
        snap.put("ok", 10).put("fail", 2).put("hard", 3).put("easy", 2)
        snap.put("mastered", 124).put("total", 1284).put("studyDays", 212)
        snap.put("heat", JSONArray(heat()))
        snap.put("forecast", JSONArray(listOf(6, 11, 4, 9, 3, 7, 12, 5, 2, 8, 6, 3, 10, 4)))
        val hz = JSONArray()
        val sz = JSONArray()
        for (k in 0..24) {
            hz.put(0.86 * (1 + 2.0 * k / 240).pow(-0.9))
            sz.put(6 + (2.0 * k * 0.45).roundToInt())
        }
        snap.put("hz", hz).put("sz", sz)
        snap.put("at", System.currentTimeMillis())
        snap.put("member", JSONObject().put("tier", "Silver").put("name", "Guest Learner").put("since", 2026).put("felt", 0.81))
        snap.put(
            "seals",
            JSONObject().put("earned", 9).put("total", 20)
                .put("latest", JSONArray()
                    .put(seal("M100", 3, "Hundred mastered"))
                    .put(seal("1K", 1, "Thousand cards"))
                    .put(seal("14", 2, "Fortnight"))
                    .put(seal("GOAL", 0, "Goal keeper")))
                .put("next", JSONObject().put("mark", "30").put("title", "One month").put("color", 0).put("have", 14).put("need", 30).put("unit", "days")),
        )
        snap.put(
            "decks",
            JSONArray()
                .put(deck("de-a1", "German · A1 Basics", 24, 6, 0, 3))
                .put(deck("es-b", "Spanish · Basics", 24, 2, 0, 4))
                .put(deck("jp-h", "Japanese · Hiragana", 69, 0, 41, 1))
                .put(deck("la-p", "Latin · Common Phrases", 30, 0, 0, 5)),
        )
        snap.put("mix", JSONObject().put("slipping", 11).put("decks", 3))
        snap.put(
            "cotd",
            JSONArray()
                .put(dayCard("c1", "Carpe diem", "Seize the day", "phrase", "From the Roman poet Horace, in his Odes", "Latin · Common Phrases", 0.98))
                .put(dayCard("c2", "das Wasser", "the water", "noun · neuter", "Ein Glas Wasser, bitte.", "German · A1 Basics", 0.97))
                .put(dayCard("c3", "Australia", "Canberra", "country", "Not Sydney: built as a compromise with Melbourne", "World Capitals", 0.99)),
        )
    }

    private fun seal(mark: String, color: Int, title: String) = JSONObject().put("mark", mark).put("color", color).put("title", title)

    private fun deck(id: String, name: String, cards: Int, slipping: Int, fresh: Int, steps: Int) =
        JSONObject().put("id", id).put("name", name).put("cards", cards).put("slipping", slipping).put("fresh", fresh).put("steps", steps)

    private fun dayCard(id: String, front: String, back: String, label: String, hook: String, deck: String, r: Double) =
        JSONObject().put("id", id).put("deck", "d").put("deckName", deck).put("front", front).put("back", back).put("label", label).put("hook", hook).put("r", r)

    /** 126 days of swipes, oldest first, with the canvas' pseudo-random levels (today is a middling day). */
    private fun heat(): List<Int> = List(126) { i ->
        val k = 125 - i
        val level = if (k == 0) 2 else {
            val x = sin(k * 12.9898 + 4.1) * 43758.5453
            val f = x - floor(x)
            when {
                f < 0.14 -> 0
                f < 0.34 -> 1
                f < 0.62 -> 2
                f < 0.86 -> 3
                else -> 4
            }
        }
        intArrayOf(0, 6, 17, 35, 58)[level]
    }
}
