package com.memorycard.memory_card.widgets

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.util.Log
import es.antonborri.home_widget.HomeWidgetFonts
import java.io.File
import java.io.InputStream
import kotlin.math.max
import kotlin.math.min

/** What the widgets borrow from the app: its Bernard display face, and card pictures (bundled or saved on the phone). */
internal object Art {
    private const val TAG = "MemoryCardWidgets"

    private fun px(ctx: Context, dp: Float) = dp * ctx.resources.displayMetrics.density

    /** Bernard MT Condensed from the app's own fonts; a bold serif when the font was not bundled. */
    fun display(ctx: Context): Typeface =
        HomeWidgetFonts.typeface(ctx, "Bernard") ?: Typeface.create(Typeface.SERIF, Typeface.BOLD)

    /** Long prompts step down in size so they still fit the face. */
    fun fit(text: String, base: Float): Float = when {
        text.length <= 10 -> base
        text.length <= 18 -> base * 0.8f
        text.length <= 30 -> base * 0.65f
        else -> base * 0.52f
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
