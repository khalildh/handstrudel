package com.handstrudel.capture

import android.content.Context
import java.io.File

/** Capture's scratch directories under `cacheDir` (iOS uses the temporary directory). */
object CaptureTempFiles {
    fun backingDir(context: Context): File = File(context.cacheDir, "backing")
    fun loopCaptureDir(context: Context): File = File(context.cacheDir, "loop-capture")

    /** Call once at launch, before any backing load or loop capture starts. */
    fun sweepCrashLeftovers(context: Context) {
        clear(backingDir(context))
        clear(loopCaptureDir(context))
    }

    internal fun clear(dir: File) {
        dir.listFiles()?.forEach { if (it.isFile) it.delete() }
    }
}
