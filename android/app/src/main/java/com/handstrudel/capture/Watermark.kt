package com.handstrudel.capture

import android.graphics.Bitmap
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.common.BitMatrix
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.handstrudel.social.model.BackingCredit

/**
 * iOS `WatermarkManager`: geometry, copy and the QR code of the recording
 * watermark. The Compose overlay (drawn only while recording, so the screen
 * capture includes it) lives in `ui/capture/StageOverlays.kt`.
 */
object Watermark {
    /** Width in dp: 140, or 178 with a play-along credit. Height 50. Right inset 16, top at 30 % of the height. */
    fun widthDp(credit: BackingCredit?): Int = if (credit == null) 140 else 178
    const val HEIGHT_DP = 50
    const val RIGHT_INSET_DP = 16
    const val TOP_FRACTION = 0.30f
    const val QR_DP = 34

    fun link(credit: BackingCredit?): String =
        credit?.let { "https://handstrudel.com/watch?v=${it.videoId.toString().lowercase()}" } ?: "https://handstrudel.com"

    fun title(credit: BackingCredit?): String = if (credit == null) "handstrudel" else "Inspired by"
    fun subtitle(credit: BackingCredit?): String = credit?.let { "@${it.username}" } ?: "scan to play 🎵"

    /** QR modules with error correction M (iOS `CIQRCodeGenerator` "M"), one-module quiet zone. */
    fun qrMatrix(text: String): BitMatrix =
        QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, 0, 0, mapOf(
            EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.M,
            EncodeHintType.MARGIN to 1,
        ))

    fun qrBitmap(text: String, sizePx: Int): Bitmap {
        val matrix = qrMatrix(text)
        val modules = matrix.width
        val scale = maxOf(1, sizePx / modules)
        val bitmap = Bitmap.createBitmap(modules * scale, modules * scale, Bitmap.Config.ARGB_8888)
        for (y in 0 until modules) for (x in 0 until modules) {
            val color = if (matrix[x, y]) 0xFF000000.toInt() else 0xFFFFFFFF.toInt()
            for (dy in 0 until scale) for (dx in 0 until scale) bitmap.setPixel(x * scale + dx, y * scale + dy, color)
        }
        return bitmap
    }
}
