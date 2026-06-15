package com.handstrudel.ui

import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import android.util.Size
import androidx.camera.core.CameraSelector
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
import com.handstrudel.engine.HandTrackingManager
import java.util.concurrent.Executors

@Composable
fun CameraPreview(
    modifier: Modifier = Modifier,
    handTracker: HandTrackingManager
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
                val cameraProvider = cameraProviderFuture.get()

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
                    cameraProvider.bindToLifecycle(
                        lifecycleOwner, cameraSelector, preview, imageAnalysis
                    )
                } catch (e: Exception) {
                    Log.e("CameraPreview", "Camera bind failed: $e")
                }
            }, ContextCompat.getMainExecutor(ctx))

            previewView
        }
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
        val rotation = imageProxy.imageInfo.rotationDegrees.toFloat()
        val w = imageProxy.width
        val h = imageProxy.height

        val matrix = Matrix().apply {
            postRotate(rotation)
            // Mirror horizontally so MediaPipe sees the same selfie-view image
            // the user is looking at on PreviewView (CameraX visually mirrors
            // the front camera preview but ImageAnalysis frames stay raw).
            postScale(-1f, 1f, w.toFloat(), h.toFloat())
        }
        val oriented = Bitmap.createBitmap(raw, 0, 0, w, h, matrix, true)
        handTracker.detectAsync(oriented, imageProxy.imageInfo.timestamp / 1_000_000)
        raw.recycle()
    } finally {
        imageProxy.close()
    }
}
