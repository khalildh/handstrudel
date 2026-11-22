package com.handstrudel.ui.studio

import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.CameraState
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.handstrudel.engine.CameraIssue
import com.handstrudel.engine.HandTrackingManager
import java.util.concurrent.Executors

@Composable
fun CameraPreview(
    modifier: Modifier = Modifier,
    handTracker: HandTrackingManager,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val executor = remember { Executors.newSingleThreadExecutor() }

    AndroidView(
        modifier = modifier,
        factory = { ctx ->
            val previewView = PreviewView(ctx).apply {
                implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                scaleType = PreviewView.ScaleType.FILL_CENTER
            }

            val cameraProviderFuture = ProcessCameraProvider.getInstance(ctx)
            cameraProviderFuture.addListener({
                val cameraProvider = try {
                    cameraProviderFuture.get()
                } catch (e: Exception) {
                    handTracker.onCameraBindFailed(e)
                    return@addListener
                }

                val preview = Preview.Builder()
                    .build()
                    .also { it.surfaceProvider = previewView.surfaceProvider }

                val imageAnalysis = ImageAnalysis.Builder()
                    .setTargetResolution(Size(480, 640))
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .build()
                    .also { analysis ->
                        analysis.setAnalyzer(executor) { imageProxy ->
                            processFrame(imageProxy, handTracker)
                        }
                    }

                val cameraSelector = CameraSelector.Builder()
                    .requireLensFacing(CameraSelector.LENS_FACING_FRONT)
                    .build()

                try {
                    cameraProvider.unbindAll()
                    val camera = cameraProvider.bindToLifecycle(
                        lifecycleOwner, cameraSelector, preview, imageAnalysis
                    )
                    // Another app holding the camera (iOS `.interrupted`); clears once it reopens.
                    camera.cameraInfo.cameraState.observe(lifecycleOwner) { state ->
                        when (state.error?.code) {
                            CameraState.ERROR_CAMERA_IN_USE, CameraState.ERROR_MAX_CAMERAS_IN_USE -> handTracker.onCameraInUse()
                            null -> if (state.type == CameraState.Type.OPEN &&
                                handTracker.cameraIssue.value == CameraIssue.INTERRUPTED
                            ) handTracker.reportCameraIssue(null)
                            else -> Unit
                        }
                    }
                } catch (e: Exception) {
                    Log.e("CameraPreview", "Camera bind failed: $e")
                    handTracker.onCameraBindFailed(e)
                }
            }, ContextCompat.getMainExecutor(ctx))

            previewView
        },
    )

    DisposableEffect(Unit) {
        onDispose { executor.shutdown() }
    }
}

private fun processFrame(imageProxy: ImageProxy, handTracker: HandTrackingManager) {
    try {
        // Canonical MediaPipe HandLandmarker camera-frame prep, matching the
        // google-ai-edge/mediapipe-samples helper: rotate the bitmap to the
        // device's display orientation ourselves and horizontally mirror it for
        // selfie view BEFORE handing it to MediaPipe.
        //
        // Relying on ImageProcessingOptions.setRotationDegrees gives flaky
        // results (hands rendered sideways) — passing a pre-oriented bitmap is
        // the supported path. After this transform, landmarks come back in the
        // same coordinate space as what the PreviewView shows, so we don't need
        // to mirror x ourselves anymore.
        val raw = imageProxy.toBitmap()
        val oriented = orientFrameForDetection(raw, imageProxy.imageInfo.rotationDegrees)
        handTracker.detectAsync(oriented, imageProxy.imageInfo.timestamp / 1_000_000)
        raw.recycle()
    } finally {
        imageProxy.close()
    }
}

/**
 * Rotate a raw front-camera frame to the display orientation and mirror it for
 * selfie view, so MediaPipe sees exactly what the PreviewView shows. Internal
 * so the instrumented hand-pipeline test drives the same transform.
 */
internal fun orientFrameForDetection(raw: Bitmap, rotationDegrees: Int): Bitmap {
    val w = raw.width
    val h = raw.height
    val matrix = Matrix().apply {
        postRotate(rotationDegrees.toFloat())
        // Mirror horizontally so MediaPipe sees the same selfie-view image
        // the user is looking at on PreviewView (CameraX visually mirrors
        // the front camera preview but ImageAnalysis frames stay raw).
        postScale(-1f, 1f, w.toFloat(), h.toFloat())
    }
    return Bitmap.createBitmap(raw, 0, 0, w, h, matrix, true)
}
