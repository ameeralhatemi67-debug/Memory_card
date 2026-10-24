package com.memorycard.memory_card.widgets

import android.app.PendingIntent
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import com.memorycard.memory_card.R
import java.nio.ByteBuffer
import java.util.Arrays
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin

/** Pieces of a widget that move. Each is a white shape in a ProgressBar the layout holds ready, tinted when placed. */
internal enum class Fx(val ids: IntArray) {
    SEAL(intArrayOf(R.id.fx_seal0, R.id.fx_seal1, R.id.fx_seal2, R.id.fx_seal3)),
    BADGE(intArrayOf(R.id.fx_badge0, R.id.fx_badge1, R.id.fx_badge2, R.id.fx_badge3)),
    FLAME(intArrayOf(R.id.fx_flame0, R.id.fx_flame1)),
    FLAME_OUTLINE(intArrayOf(R.id.fx_flameo0)),
    PULSE(intArrayOf(R.id.fx_pulse0, R.id.fx_pulse1, R.id.fx_pulse2, R.id.fx_pulse3)),
    SHEEN(intArrayOf(R.id.fx_sheen0)),
    SHEEN_WIDE(intArrayOf(R.id.fx_sheenw0, R.id.fx_sheenw1, R.id.fx_sheenw2)),
}

/** A piece that moves, placed in dp over a scene, with the colours it takes by day and by night. */
internal class Sprite(val fx: Fx, val x: Float, val y: Float, val w: Float, val h: Float, val day: Int, val night: Int)

/** A tap target in dp, with what it does. */
internal class Hit(val x: Float, val y: Float, val w: Float, val h: Float, val radius: Float, val pi: PendingIntent, val label: String, val ripple: Boolean = true)

/** Where a stroke of ink goes: the main ink (0), the ink for lettering on ink (1), or a colour that never changes (2). */
internal class Brush(val layer: Int, val color: Int)

internal enum class Align { START, CENTER, END }

/**
 * One drawn face of a widget at one size. Everything is drawn in dp onto three layers: [fg], the ink of the face
 * (dark on paper, light on ink); [on], the ink for lettering laid over [fg] shapes (the colour of the face itself);
 * and [art], colours that never change (red, green, the grade colours). The layers are tinted by the layout, so a
 * theme change needs no redraw: the app is not even running when the phone goes dark.
 */
internal class Scene(
    val ctx: Context,
    val w: Float,
    val h: Float,
    val look: Look,
    val surface: Surface,
    /** True when the layout will really run the moving pieces; false for stills (previews, old phones, motion off). */
    val animated: Boolean,
) {
    val d: Float = ctx.resources.displayMetrics.density
    val wPx = max(1, (w * d).roundToInt())
    val hPx = max(1, (h * d).roundToInt())
    val fg: Bitmap = Bitmap.createBitmap(wPx, hPx, Bitmap.Config.ALPHA_8)
    val on: Bitmap = Bitmap.createBitmap(wPx, hPx, Bitmap.Config.ALPHA_8)
    val art: Bitmap = Bitmap.createBitmap(wPx, hPx, Bitmap.Config.ARGB_8888)
    private val cf = Canvas(fg)
    private val co = Canvas(on)
    private val ca = Canvas(art)
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val tp = TextPaint(Paint.ANTI_ALIAS_FLAG)
    private val capCache = HashMap<String, Float>()

    val hits = ArrayList<Hit>()
    val sprites = ArrayList<Sprite>()

    /** What a screen reader says for the whole widget. */
    var description: String = ""

    /** What a tap anywhere else does (opens the app); set by the widget. */
    var anywhere: PendingIntent? = null

    /** The widget is a pill: narrow enough that round corners mean a full semicircle. */
    val pill: Boolean get() = w < 96f && look.corners == "round"

    // -------------------------------------------------------------------------------------------- brushes

    val display: Typeface = Art.display(ctx)
    val ui: Typeface = Typeface.create("sans-serif-condensed", Typeface.NORMAL)
    val uiBold: Typeface = Typeface.create("sans-serif-condensed", Typeface.BOLD)
    val uiItalic: Typeface = Typeface.create("sans-serif-condensed", Typeface.ITALIC)

    fun ink(a: Float = 1f) = Brush(0, white(a))
    fun onInk(a: Float = 1f) = Brush(1, white(a))
    fun col(argb: Int) = Brush(2, argb)
    val accent: Brush get() = col(look.accent)

    private fun white(a: Float) = (((a.coerceIn(0f, 1f) * 255f).roundToInt()) shl 24) or 0x00FFFFFF

    /** Which layers have been drawn on: a layer nothing was drawn on is not sent to the launcher at all. */
    val used = BooleanArray(3)

    private fun cv(b: Brush): Canvas {
        used[b.layer] = true
        return when (b.layer) {
            0 -> cf
            1 -> co
            else -> ca
        }
    }

    private fun fill(b: Brush): Paint {
        paint.reset()
        paint.isAntiAlias = true
        paint.style = Paint.Style.FILL
        paint.color = b.color
        return paint
    }

    private fun line(b: Brush, widthDp: Float, round: Boolean = true): Paint {
        paint.reset()
        paint.isAntiAlias = true
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = widthDp * d
        paint.strokeCap = if (round) Paint.Cap.ROUND else Paint.Cap.BUTT
        paint.strokeJoin = Paint.Join.ROUND
        paint.color = b.color
        return paint
    }

    // -------------------------------------------------------------------------------------------- shapes

    /** A rectangle with rounded corners (radius in dp, never more than half the short side). */
    fun rect(b: Brush, x: Float, y: Float, rw: Float, rh: Float, r: Float = 0f) {
        val rad = min(r, min(rw, rh) / 2f) * d
        cv(b).drawRoundRect(x * d, y * d, (x + rw) * d, (y + rh) * d, rad, rad, fill(b))
    }

    /** A rounded rectangle drawn as an outline. */
    fun outline(b: Brush, x: Float, y: Float, rw: Float, rh: Float, r: Float, stroke: Float, dash: Float = 0f, gap: Float = 0f) {
        val p = line(b, stroke, false)
        if (dash > 0f) p.pathEffect = DashPathEffect(floatArrayOf(dash * d, gap * d), 0f)
        val rad = min(r, min(rw, rh) / 2f) * d
        val half = stroke * d / 2f
        cv(b).drawRoundRect(x * d + half, y * d + half, (x + rw) * d - half, (y + rh) * d - half, rad, rad, p)
    }

    fun pill(b: Brush, x: Float, y: Float, pw: Float, ph: Float) = rect(b, x, y, pw, ph, ph / 2f)

    fun circle(b: Brush, cx: Float, cy: Float, r: Float) {
        cv(b).drawCircle(cx * d, cy * d, r * d, fill(b))
    }

    /** A stroked arc; angles in degrees from 3 o'clock, so a ring that starts at 12 o'clock begins at -90. */
    fun arc(b: Brush, cx: Float, cy: Float, r: Float, stroke: Float, start: Float, sweep: Float, round: Boolean = true) {
        val rr = r * d
        cv(b).drawArc(RectF(cx * d - rr, cy * d - rr, cx * d + rr, cy * d + rr), start, sweep, false, line(b, stroke, round))
    }

    fun ring(b: Brush, cx: Float, cy: Float, r: Float, stroke: Float) = arc(b, cx, cy, r, stroke, 0f, 360f, false)

    fun stroke(b: Brush, x1: Float, y1: Float, x2: Float, y2: Float, width: Float) {
        cv(b).drawLine(x1 * d, y1 * d, x2 * d, y2 * d, line(b, width))
    }

    /** The wax seal: 48 points alternating between 46 % and 41 % of [size] from its centre (the app's seal). */
    fun seal(b: Brush, cx: Float, cy: Float, size: Float) {
        val path = Path()
        for (i in 0 until 48) {
            val a = i / 48f * 2f * PI.toFloat()
            val r = size * (if (i % 2 == 1) 0.41f else 0.46f)
            val x = (cx + cos(a) * r) * d
            val y = (cy + sin(a) * r) * d
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        path.close()
        cv(b).drawPath(path, fill(b))
    }

    /** One of the shop's badge shapes, [size] across (the polar curves of the Widgets canvas). */
    fun badge(b: Brush, shape: Int, cx: Float, cy: Float, size: Float, turn: Float = 0f) {
        val k = size / 100f * 1.25f
        val path = Path()
        val n = if (shape == 2) 120 else 96
        for (i in 0 until n) {
            val a = i / n.toFloat() * 2f * PI.toFloat()
            val r = badgeRadius(shape, a) * k
            val x = (cx + cos(a + turn) * r * (1f)) * d
            val y = (cy + sin(a + turn) * r) * d
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        path.close()
        cv(b).drawPath(path, fill(b))
    }

    private fun badgeRadius(shape: Int, a: Float): Float = when (shape) {
        0 -> 31f + 3.2f * cos(8f * a)
        1 -> {
            val sq = (abs(cos(a)).pow(4) + abs(sin(a)).pow(4)).pow(-0.25f)
            31f * sq + 2.2f * sin(4f * a + 0.8f)
        }
        2 -> 29f + 5f * cos(12f * a)
        else -> 31f + 3.5f * sin(3f * a) + 2f * cos(5f * a + 1f)
    }

    /** A vector drawable of the app's, white-tinted by [b] unless [tint] is off (then it keeps its own colours). */
    fun vec(b: Brush, res: Int, x: Float, y: Float, vw: Float, vh: Float, tint: Boolean = true) {
        val drawable = ctx.getDrawable(res)?.mutate() ?: return
        if (tint) drawable.setTint(b.color)
        drawable.setBounds((x * d).roundToInt(), (y * d).roundToInt(), ((x + vw) * d).roundToInt(), ((y + vh) * d).roundToInt())
        drawable.draw(cv(b))
    }

    /** A picture (already rounded by Art.picture) fitted into a box and centred in it, or pinned to its left. */
    fun picture(bitmap: Bitmap, x: Float, y: Float, bw: Float, bh: Float, center: Boolean = true) {
        val s = min(bw * d / bitmap.width, bh * d / bitmap.height)
        val pw = bitmap.width * s
        val ph = bitmap.height * s
        val left = x * d + if (center) (bw * d - pw) / 2f else 0f
        val top = y * d + (bh * d - ph) / 2f
        paint.reset()
        paint.isFilterBitmap = true
        used[2] = true
        ca.drawBitmap(bitmap, null, RectF(left, top, left + pw, top + ph), paint)
    }

    // -------------------------------------------------------------------------------------------- text

    /** Small print follows the phone's font size setting (a little: widgets have no room to grow); the display face does not. */
    private val smallScale: Float = ctx.resources.configuration.fontScale.coerceIn(1f, 1.2f)

    private fun scaleOf(face: Typeface) = if (face === ui || face === uiBold || face === uiItalic) smallScale else 1f

    private fun textPaint(b: Brush, size: Float, face: Typeface, spacing: Float): TextPaint {
        tp.reset()
        tp.isAntiAlias = true
        tp.typeface = face
        tp.textSize = size * d * scaleOf(face)
        tp.color = b.color
        tp.letterSpacing = if (size > 0f) spacing / size else 0f
        return tp
    }

    private fun capHeight(face: Typeface, size: Float): Float = capCache.getOrPut("${face.hashCode()}/$size") {
        val p = TextPaint(Paint.ANTI_ALIAS_FLAG)
        p.typeface = face
        p.textSize = size * d * scaleOf(face)
        val r = Rect()
        p.getTextBounds("H", 0, 1, r)
        r.height() / d
    }

    /** How wide [s] is (dp) at [size]. */
    fun measure(s: String, size: Float, face: Typeface = display, spacing: Float = 0f): Float =
        textPaint(ink(), size, face, spacing).measureText(s) / d

    /**
     * One line of text. [y] is the baseline, or the middle of the capital letters when [middle]. Text wider than
     * [maxW] steps down to 60 % of its size, then is cut with an ellipsis. Returns the width drawn (dp).
     */
    fun text(
        b: Brush,
        s: String,
        x: Float,
        y: Float,
        size: Float,
        face: Typeface = display,
        align: Align = Align.START,
        maxW: Float = Float.MAX_VALUE,
        spacing: Float = 0f,
        middle: Boolean = false,
    ): Float {
        if (s.isEmpty()) return 0f
        var sz = size
        var p = textPaint(b, sz, face, spacing)
        var width = p.measureText(s) / d
        if (width > maxW) {
            // A hair under the fit: measuring at another size can come out a pixel wider, and that would cost a letter.
            sz = max(size * 0.6f, size * maxW / width * 0.985f)
            p = textPaint(b, sz, face, spacing)
            width = p.measureText(s) / d
        }
        var shown = s
        if (width > maxW + 0.5f) {
            shown = TextUtils.ellipsize(s, p, maxW * d, TextUtils.TruncateAt.END).toString()
            width = p.measureText(shown) / d
        }
        val left = when (align) {
            Align.START -> x
            Align.CENTER -> x - width / 2f
            Align.END -> x - width
        }
        val base = if (middle) y + capHeight(face, sz) / 2f else y
        cv(b).drawText(shown, left * d, base * d, p)
        return width
    }

    /** Wrapped text in a box [tw] wide, at most [maxLines] lines, the last cut with an ellipsis. Returns the height used (dp). */
    fun lines(
        b: Brush,
        s: String,
        x: Float,
        y: Float,
        tw: Float,
        size: Float,
        face: Typeface = ui,
        maxLines: Int = 2,
        align: Align = Align.START,
        lineHeight: Float = 1.1f,
    ): Float {
        if (s.isEmpty()) return 0f
        val p = textPaint(b, size, face, 0f)
        val layout = StaticLayout.Builder.obtain(s, 0, s.length, p, max(1, (tw * d).roundToInt()))
            .setMaxLines(maxLines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .setLineSpacing(0f, lineHeight)
            .setAlignment(
                when (align) {
                    Align.START -> Layout.Alignment.ALIGN_NORMAL
                    Align.CENTER -> Layout.Alignment.ALIGN_CENTER
                    Align.END -> Layout.Alignment.ALIGN_OPPOSITE
                },
            )
            .build()
        val canvas = cv(b)
        canvas.save()
        canvas.translate(x * d, y * d)
        layout.draw(canvas)
        canvas.restore()
        return layout.height / d
    }

    /** Draws [block] on every layer, cut to a rounded rectangle (a bar whose segments share rounded ends). */
    fun clipped(x: Float, y: Float, cw: Float, ch: Float, r: Float, block: () -> Unit) {
        val path = Path()
        val rad = min(r, min(cw, ch) / 2f) * d
        path.addRoundRect(RectF(x * d, y * d, (x + cw) * d, (y + ch) * d), rad, rad, Path.Direction.CW)
        val all = arrayOf(cf, co, ca)
        for (c in all) {
            c.save()
            c.clipPath(path)
        }
        block()
        for (c in all) c.restore()
    }

    /** Draws [block] turned [deg] degrees about a point (dp), on the layer of [b]. */
    fun rotated(b: Brush, deg: Float, cx: Float, cy: Float, block: () -> Unit) {
        val c = cv(b)
        c.save()
        c.rotate(deg, cx * d, cy * d)
        block()
        c.restore()
    }

    // -------------------------------------------------------------------------------------------- colours as pieces need them

    /** The face's own colour, the main ink and the over-ink, by day (first) and by night (second). */
    fun faceTones(): Triple<Pair<Int, Int>, Pair<Int, Int>, Pair<Int, Int>> {
        val (df, dm, dov) = faceColors(look.day)
        val (nf, nm, nov) = faceColors(look.night)
        return Triple(df to nf, dm to nm, dov to nov)
    }

    /** What [a] of the main ink looks like laid over the face, as one solid colour (day, night): a moving piece needs a colour, not an alpha. */
    fun shade(a: Float): Pair<Int, Int> {
        val (face, main, _) = faceTones()
        return blend(face.first, main.first, a) to blend(face.second, main.second, a)
    }

    /** Light for a moving highlight: white over a dark face, a shadow over a light one (day, night). */
    fun glint(onMain: Boolean = false): Pair<Int, Int> {
        val (faceTone, mainTone, _) = faceTones()
        val face = if (onMain) mainTone else faceTone
        fun pick(c: Int): Int {
            val l = 0.299 * ((c shr 16) and 0xFF) + 0.587 * ((c shr 8) and 0xFF) + 0.114 * (c and 0xFF)
            return if (l < 128) 0xFFFFFFFF.toInt() else 0xFF000000.toInt()
        }
        return pick(face.first) to pick(face.second)
    }

    private fun blend(base: Int, top: Int, a: Float): Int {
        fun ch(shift: Int): Int {
            val b = (base shr shift) and 0xFF
            val t = (top shr shift) and 0xFF
            return (b + (t - b) * a).roundToInt().coerceIn(0, 255)
        }
        return (0xFF shl 24) or (ch(16) shl 16) or (ch(8) shl 8) or ch(0)
    }

    /** How tall wrapped text would be (dp), without drawing it. */
    fun linesHeight(s: String, tw: Float, size: Float, face: Typeface = ui, maxLines: Int = 2, lineHeight: Float = 1.1f): Float {
        if (s.isEmpty()) return 0f
        val p = textPaint(ink(), size, face, 0f)
        return StaticLayout.Builder.obtain(s, 0, s.length, p, max(1, (tw * d).roundToInt()))
            .setMaxLines(maxLines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .setLineSpacing(0f, lineHeight)
            .build().height / d
    }

    /** Wrapped text centred vertically in a box [boxH] tall that starts at [y]. Returns the height used. */
    fun linesMiddle(
        b: Brush, s: String, x: Float, y: Float, tw: Float, boxH: Float, size: Float,
        face: Typeface = ui, maxLines: Int = 2, align: Align = Align.START, lineHeight: Float = 1.1f,
    ): Float {
        val hgt = min(boxH, linesHeight(s, tw, size, face, maxLines, lineHeight))
        return lines(b, s, x, y + (boxH - hgt) / 2f, tw, size, face, maxLines, align, lineHeight)
    }

    // -------------------------------------------------------------------------------------------- moving pieces and taps

    /**
     * A moving piece. When the layout will run it, it is recorded and drawn by the launcher; otherwise [still] draws
     * the same thing into the layers, so a widget looks right on an old phone, with motion off, and in a preview.
     * The piece is tinted [day] on a day-mode phone and [night] at night.
     */
    fun sprite(fx: Fx, x: Float, y: Float, sw: Float, sh: Float, day: Int, night: Int = day, still: () -> Unit) {
        val index = sprites.count { it.fx == fx }
        if (animated && index < fx.ids.size && sw > 0f && sh > 0f) sprites.add(Sprite(fx, x, y, sw, sh, day, night)) else still()
    }

    fun hit(x: Float, y: Float, hw: Float, hh: Float, pi: PendingIntent, label: String = "", radius: Float = 14f, ripple: Boolean = true) {
        if (hits.size < 8 && hw > 0f && hh > 0f) hits.add(Hit(x, y, hw, hh, radius, pi, label, ripple))
    }

    /** The mark of this drawing, to tell a refresh that changed nothing from one that did. */
    fun fingerprint(): String {
        var h = 17
        for (bm in arrayOf(fg, on, art)) {
            val bb = ByteBuffer.allocate(bm.byteCount)
            bm.copyPixelsToBuffer(bb)
            h = h * 31 + Arrays.hashCode(bb.array())
        }
        val extra = StringBuilder()
        for (s in sprites) extra.append(s.fx.name).append(s.x).append(s.y).append(s.w).append(s.day).append(';')
        for (t in hits) extra.append(t.x).append(t.y).append(t.w).append(t.label).append(';')
        return "${h * 31 + extra.toString().hashCode()}:${wPx}x$hPx"
    }

    // -------------------------------------------------------------------------------------------- flattening

    /** The ink colours of a face in [tone]: its surface, the main ink and the ink that lies on it. */
    fun faceColors(tone: Tone): Triple<Int, Int, Int> = when (surface) {
        Surface.INK -> Triple(tone.ink, tone.paper, tone.ink)
        else -> Triple(tone.paper, tone.ink, tone.paper)
    }

    /** The whole widget as one picture, for the previews (the home screen composes the same layers itself). */
    fun flatten(night: Boolean): Bitmap {
        val tone = if (night) look.night else look.day
        val (face, main, over) = faceColors(tone)
        val out = Bitmap.createBitmap(wPx, hPx, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        if (surface != Surface.CLEAR) {
            val radius = (if (pill) 999f else look.radius) * d
            p.color = (face and 0x00FFFFFF) or ((look.opacity * 255 / 100) shl 24)
            c.drawRoundRect(RectF(0f, 0f, wPx.toFloat(), hPx.toFloat()), min(radius, min(wPx, hPx) / 2f), min(radius, min(wPx, hPx) / 2f), p)
        }
        p.color = main
        c.drawBitmap(fg, 0f, 0f, p)
        p.color = over
        c.drawBitmap(on, 0f, 0f, p)
        c.drawBitmap(art, 0f, 0f, null)
        return out
    }

    companion object {
        /** Moving pieces need the size setters of Android 12. */
        val canAnimate: Boolean get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
    }
}
