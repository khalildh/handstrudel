package com.handstrudel.capture

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * Foreground service (type `mediaProjection`) that owns stage capture.
 * Owner: capture (WS4). Declared in the manifest in Phase 0; stub until WS4.
 */
class CaptureService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        stopSelf(startId)
        return START_NOT_STICKY
    }
}
