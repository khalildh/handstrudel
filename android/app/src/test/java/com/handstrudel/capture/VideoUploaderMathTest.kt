package com.handstrudel.capture

import com.handstrudel.capture.upload.VideoUploader
import org.junit.Assert.assertEquals
import org.junit.Test

class VideoUploaderMathTest {
    @Test fun renderSizeIs720WideWithEvenHeight() {
        assertEquals(720 to 1280, VideoUploader.renderSize(1080, 1920))
        assertEquals(720 to 1600, VideoUploader.renderSize(1080, 2400))
        // 1179×2556 (iPhone 15) → 1560.9… → even 1560
        assertEquals(720 to 1560, VideoUploader.renderSize(1179, 2556))
        // 721×1001 → 999.6… /2 = 499.8 → 500 → 1000
        assertEquals(720 to 1000, VideoUploader.renderSize(721, 1001))
        for (h in 1000..1100) assertEquals(0, VideoUploader.renderSize(1001, h).second % 2)
    }

    @Test fun targetBitrate() {
        assertEquals(2_500_000, VideoUploader.targetVideoBitrate(1.0))
        assertEquals(2_500_000, VideoUploader.targetVideoBitrate(0.2)) // max(duration, 1)
        assertEquals(2_500_000, VideoUploader.targetVideoBitrate(7.0))
        // 60 s: 12 MiB·8/60 − 128 k = 1 677 721.6 − 128 000
        assertEquals(1_549_721, VideoUploader.targetVideoBitrate(60.0))
    }
}
