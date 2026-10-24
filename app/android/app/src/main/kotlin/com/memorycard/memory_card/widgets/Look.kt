package com.memorycard.memory_card.widgets

import com.memorycard.memory_card.R
import org.json.JSONObject

/** What a widget's face is made of: paper (a light card), ink (a dark one), or nothing (badges on the wallpaper). */
internal enum class Surface { PAPER, INK, CLEAR }

/** The app's "inverse ink" tokens for one theme (lib/ui/theme.dart): the paper, and the ink that lies on it. */
internal class Tone(val paper: Int, val ink: Int)

internal val TONE_LIGHT = Tone(0xFFF1F1F1.toInt(), 0xFF333333.toInt())
internal val TONE_DARK = Tone(0xFF151515.toInt(), 0xFFF1F1F1.toInt())

/**
 * How much ink each kind of grey is: widgets draw in one ink and let its strength make the greys, so every grey
 * follows the theme (0.7 of ink on paper is the muted text grey, 0.085 the soft panel).
 */
internal object Shade {
    const val MUTED = 0.70f
    const val DIM = 0.45f
    const val TRACK = 0.19f
    const val LINE = 0.15f
    const val SOFT = 0.085f
}

/** Colours that are the same in both themes (lib/ui/theme.dart). */
internal object Hue {
    const val RED = 0xFFD35F5F.toInt()
    const val AGAIN = 0xFFFF8080.toInt()
    const val GOOD = 0xFF8BD3A0.toInt()
    const val BLUE = 0xFF80AEFF.toInt()
    const val PEACH = 0xFFFFC680.toInt()
    const val GRAPHITE = 0xFF333333.toInt()
    const val PAPER = 0xFFF1F1F1.toInt()
    const val SILVER = 0xFFCDD2D8.toInt()
    const val STRIPE = 0xFF1E1E1E.toInt()
}

/**
 * How the user wants the widgets to look (Settings › Home screen widgets), as the app's snapshot carries it:
 * theme, accent, corners, background strength, motion, and which face each widget wears.
 */
internal class Look(j: JSONObject? = null) {
    /** auto follows the phone; light or dark holds one theme whatever the phone does. */
    val theme: String = j?.optString("theme", "auto")?.takeIf { it == "light" || it == "dark" } ?: "auto"

    /** The colour of the seal, flame and rings. */
    val accent: Int = when (j?.optString("accent")) {
        "orange" -> 0xFFE08A3E.toInt()
        "green" -> 0xFF4E9E68.toInt()
        "blue" -> 0xFF5C86DA.toInt()
        "violet" -> 0xFF8A6FD4.toInt()
        else -> Hue.RED
    }

    val corners: String = j?.optString("corners", "round")?.takeIf { it == "soft" || it == "square" } ?: "round"

    /** How solid a widget's face is, 30–100 %. */
    val opacity: Int = (j?.optInt("opacity", 100) ?: 100).coerceIn(30, 100)

    /** Things that move on the home screen (the app's own reduced-motion setting turns them off too). */
    val motion: Boolean = j?.optBoolean("motion", true) ?: true

    /** Quick card: the prompt and the buttons side by side instead of stacked. */
    val quickSide: Boolean = j?.optString("quick") == "side"

    private val surfaces: JSONObject? = j?.optJSONObject("surfaces")

    /** The face of widget [kind]: the user's pick, else the one it was designed with. */
    fun surface(kind: String, natural: Surface): Surface = when (surfaces?.optString(kind)) {
        "paper" -> Surface.PAPER
        "ink" -> Surface.INK
        else -> natural
    }

    /** The tone a face uses when the phone is in day mode, and in night mode. */
    val day: Tone get() = if (theme == "dark") TONE_DARK else TONE_LIGHT
    val night: Tone get() = if (theme == "light") TONE_LIGHT else TONE_DARK

    /** Corner radius (dp) of a widget's face. */
    val radius: Float get() = when (corners) { "soft" -> 14f; "square" -> 6f; else -> 22f }

    /** A smaller thing drawn on the face (a button, a panel) keeps its proportion to the face's corners. */
    fun inner(r: Float): Float = when (corners) { "soft" -> r * 0.65f; "square" -> r * 0.3f; else -> r }

    /** The surface shape to tint; widgets narrower than a pill's worth are drawn as pills when the corners are round. */
    fun faceRes(pill: Boolean): Int = when (corners) {
        "soft" -> R.drawable.wg_bg_soft
        "square" -> R.drawable.wg_bg_square
        else -> if (pill) R.drawable.wg_bg_pill else R.drawable.wg_bg_round
    }

    /** The ripple that fits those corners. */
    fun rippleRes(pill: Boolean): Int = when (corners) {
        "soft" -> R.drawable.wg_ripple_14
        "square" -> R.drawable.wg_ripple_6
        else -> if (pill) R.drawable.wg_ripple_pill else R.drawable.wg_ripple_22
    }
}
