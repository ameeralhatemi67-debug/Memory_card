package com.memorycard.memory_card.widgets

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.util.Log
import androidx.glance.text.TextAlign
import es.antonborri.home_widget.HomeWidgetFonts
import java.io.File
import java.io.InputStream
import kotlin.math.max
import kotlin.math.min

/** Everything the widgets draw themselves: Bernard display text, the progress ring, the DONE stamp, pictures. */
internal object Art {
    private const val TAG = "MemoryCardWidgets"
    private const val RED = 0xFFD35F5F.toInt()

    private fun px(ctx: Context, dp: Float) = dp * ctx.resources.displayMetrics.density

    /** Bernard MT Condensed from the app's own fonts; a bold serif when the font was not bundled. */
    fun display(ctx: Context): Typeface =
        HomeWidgetFonts.typeface(ctx, "Bernard") ?: Typeface.create(Typeface.SERIF, Typeface.BOLD)

    /** Display text as a white mask, for the layout to tint (so it follows the light and dark theme). */
    fun text(
        ctx: Context,
        text: String,
        sp: Float,
        maxWidthDp: Float,
        maxLines: Int = 1,
        center: Boolean = false,
        mono: Boolean = false,
    ): Bitmap = HomeWidgetFonts.textBitmap(
        ctx,
        if (mono) Typeface.create(Typeface.MONOSPACE, Typeface.BOLD) else display(ctx),
        text,
        fontSizeSp = sp,
        textAlign = if (center) TextAlign.Center else null,
        maxLines = maxLines,
        maxWidthDp = maxWidthDp,
    )

    /** Long prompts step down in size so they still fit the face. */
    fun fit(text: String, base: Float): Float = when {
        text.length <= 10 -> base
        text.length <= 18 -> base * 0.8f
        text.length <= 30 -> base * 0.65f
        else -> base * 0.52f
    }

    /** The day's progress: a red arc over the seal's track (radius 34, stroke 5 on the seal's 100 grid). */
    fun arc(ctx: Context, sizeDp: Float, fraction: Float): Bitmap {
        val size = max(1, px(ctx, sizeDp).toInt())
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val f = fraction.coerceIn(0f, 1f)
        if (f <= 0f) return bitmap
        val s = size / 100f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 5f * s
            strokeCap = Paint.Cap.ROUND
            color = RED
        }
        val r = 34f * s
        Canvas(bitmap).drawArc(RectF(50f * s - r, 50f * s - r, 50f * s + r, 50f * s + r), -90f, 360f * f, false, paint)
        return bitmap
    }

    /** "DONE", stamped at -12° in paper white, sized for a seal of [sealDp]. */
    fun doneStamp(ctx: Context, sealDp: Float): Bitmap {
        val size = max(1, px(ctx, sealDp * 0.7f).toInt())
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = display(ctx)
            textSize = px(ctx, sealDp * 0.2f)
            color = Color.parseColor("#F1F1F1")
            textAlign = Paint.Align.CENTER
            letterSpacing = 0.05f
        }
        val c = Canvas(bitmap)
        c.rotate(-12f, size / 2f, size / 2f)
        c.drawText("DONE", size / 2f, size / 2f - (paint.descent() + paint.ascent()) / 2f, paint)
        return bitmap
    }

    /**
     * A card picture: bundled (`asset:…`, read from the app's Flutter assets) or saved on the phone (a file
     * path). Scaled to at most [maxPx] on its long side with rounded corners; [blur] smears it the cheap way
     * (down to a few pixels and back up) for pictures that wait for the reveal. Null when it cannot be read.
     */
    fun picture(ctx: Context, src: String, maxPx: Int, blur: Boolean = false): Bitmap? {
        fun open(): InputStream? =
            if (src.startsWith("asset:")) ctx.assets.open("flutter_assets/" + src.removePrefix("asset:"))
            else File(src).takeIf { it.isFile }?.inputStream()
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            (open() ?: return null).use { BitmapFactory.decodeStream(it, null, bounds) }
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
            var sample = 1
            while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxPx) sample *= 2
            val raw = open()?.use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample }) }
                ?: return null
            val scale = min(1f, maxPx / max(raw.width, raw.height).toFloat())
            var b = if (scale < 1f) {
                Bitmap.createScaledBitmap(raw, max(1, (raw.width * scale).toInt()), max(1, (raw.height * scale).toInt()), true)
            } else {
                raw
            }
            if (blur) {
                repeat(2) {
                    val small = Bitmap.createScaledBitmap(b, max(1, b.width / 14), max(1, b.height / 14), true)
                    b = Bitmap.createScaledBitmap(small, b.width, b.height, true)
                }
            }
            rounded(b, px(ctx, 10f))
        } catch (e: Exception) {
            Log.w(TAG, "Could not read the picture $src", e)
            null
        }
    }

    private fun rounded(b: Bitmap, radius: Float): Bitmap {
        val out = Bitmap.createBitmap(b.width, b.height, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { shader = BitmapShader(b, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP) }
        Canvas(out).drawRoundRect(RectF(0f, 0f, b.width.toFloat(), b.height.toFloat()), radius, radius, paint)
        return out
    }
}
