package com.handstrudel.capture

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.Surface
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Foreground service (type `mediaProjection`) that owns the studio session's
 * [MediaProjection]. Android requires the service to be in the foreground
 * before `getMediaProjection`. Owner: capture (WS4).
 */
class CaptureService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val code = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
                @Suppress("DEPRECATION")
                val data: Intent? = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
                else intent.getParcelableExtra(EXTRA_DATA)
                try {
                    goForeground()
                    val manager = getSystemService(MediaProjectionManager::class.java)
                    val projection = data?.let { manager.getMediaProjection(code, it) }
                        ?: throw IllegalStateException("Screen capture permission wasn't granted.")
                    CaptureProjection.attach(projection)
                } catch (e: Exception) {
                    Log.w(TAG, "Couldn't start the projection", e)
                    CaptureProjection.failStart(e)
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf(startId)
                }
            }
            else -> {
                CaptureProjection.release()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        CaptureProjection.release()
        super.onDestroy()
    }

    private fun goForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Recording", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Shown while HandStrudel can record the stage."
                },
            )
        }
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.presence_video_online)
            .setContentTitle("HandStrudel can record the stage")
            .setContentText("Recording access ends when you close the session.")
            .setOngoing(true)
            .setSilent(true)
            .build()
        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
    }

    companion object {
        private const val TAG = "CaptureService"
        private const val CHANNEL_ID = "capture"
        private const val NOTIFICATION_ID = 4104
        private const val ACTION_START = "com.handstrudel.capture.START"
        private const val ACTION_STOP = "com.handstrudel.capture.STOP"
        private const val EXTRA_RESULT_CODE = "resultCode"
        private const val EXTRA_DATA = "data"

        fun start(context: Context, resultCode: Int, data: Intent) {
            val intent = Intent(context, CaptureService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_RESULT_CODE, resultCode)
                .putExtra(EXTRA_DATA, data)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            val wasActive = CaptureProjection.isActive
            CaptureProjection.release()
            if (wasActive) runCatching { context.startService(Intent(context, CaptureService::class.java).setAction(ACTION_STOP)) }
        }
    }
}

/**
 * Process-wide holder of the session's projection and its single
 * [VirtualDisplay]. Android 14 lets a projection create only one virtual display,
 * so takes swap the display's surface instead of creating a new one.
 */
object CaptureProjection {
    private const val TAG = "CaptureProjection"
    private val main = Handler(Looper.getMainLooper())
    private val _projection = MutableStateFlow<MediaProjection?>(null)
    val projection: StateFlow<MediaProjection?> = _projection
    val isActive: Boolean get() = _projection.value != null
    private var starting: CompletableDeferred<MediaProjection>? = null
    private var display: VirtualDisplay? = null

    /** Called on the main thread when the system or the user stops the projection. */
    @Volatile var onStopped: (() -> Unit)? = null

    private val callback = object : MediaProjection.Callback() {
        override fun onStop() {
            Log.i(TAG, "Projection stopped")
            main.post {
                val wasActive = _projection.value != null
                clear()
                if (wasActive) onStopped?.invoke()
            }
        }
    }

    fun beginStart(): CompletableDeferred<MediaProjection> =
        CompletableDeferred<MediaProjection>().also { starting = it }

    internal fun attach(projection: MediaProjection) {
        projection.registerCallback(callback, main)
        _projection.value = projection
        starting?.complete(projection)
        starting = null
    }

    internal fun failStart(error: Exception) {
        starting?.completeExceptionally(error)
        starting = null
    }

    /**
     * Points the session's virtual display at [surface], creating it on first use.
     * Pass null between takes so nothing is rendered. Main thread.
     */
    fun bindSurface(surface: Surface?, width: Int, height: Int, densityDpi: Int) {
        val projection = _projection.value ?: throw IllegalStateException("Screen capture isn't active.")
        val current = display
        if (current == null) {
            if (surface == null) return
            display = projection.createVirtualDisplay(
                "HandStrudel stage", width, height, densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, surface, null, main,
            )
        } else {
            if (surface != null) current.resize(width, height, densityDpi)
            current.surface = surface
        }
    }

    fun release() {
        val projection = _projection.value
        clear()
        try {
            projection?.unregisterCallback(callback)
            projection?.stop()
        } catch (e: Exception) {
            Log.w(TAG, "stop", e)
        }
    }

    private fun clear() {
        display?.release()
        display = null
        _projection.value = null
        starting?.completeExceptionally(IllegalStateException("Screen capture stopped."))
        starting = null
    }
}
