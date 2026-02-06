package com.example.hangboard_auto_timer

import android.content.Context
import android.os.SystemClock
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerOptions
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import java.util.concurrent.Executors

/**
 * Handles camera setup, MediaPipe Pose detection, gesture classification,
 * EMA smoothing, and emitting GestureEvents to Flutter.
 */
class GestureDetector(private val context: Context) {

    companion object {
        private const val TAG = "GestureDetector"
        private const val MARGIN_Y = 0.05f
        private const val CONF_MIN = 0.5f
        private const val EMA_ALPHA = 0.3f
    }

    private var cameraProvider: ProcessCameraProvider? = null
    private var poseLandmarker: PoseLandmarker? = null
    private var isProcessing = false
    private var isPaused = false

    // EMA smoothed values for Y coordinates
    private var smoothedLeftShoulderY: Float? = null
    private var smoothedRightShoulderY: Float? = null
    private var smoothedLeftWristY: Float? = null
    private var smoothedRightWristY: Float? = null

    private val executor = Executors.newSingleThreadExecutor()

    fun start(frontCamera: Boolean, onEvent: (Map<String, Any?>) -> Unit) {
        initPoseLandmarker()

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()

            val cameraSelector = if (frontCamera) {
                CameraSelector.DEFAULT_FRONT_CAMERA
            } else {
                CameraSelector.DEFAULT_BACK_CAMERA
            }

            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()

            imageAnalysis.setAnalyzer(executor) { imageProxy ->
                if (!isProcessing && !isPaused) {
                    isProcessing = true
                    processFrame(imageProxy, onEvent)
                } else {
                    imageProxy.close()
                }
            }

            try {
                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(
                    context as LifecycleOwner,
                    cameraSelector,
                    imageAnalysis
                )
            } catch (e: Exception) {
                Log.e(TAG, "Camera binding failed", e)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    fun stop() {
        cameraProvider?.unbindAll()
        poseLandmarker?.close()
        poseLandmarker = null
        executor.shutdown()
        resetSmoothing()
    }

    fun pause() {
        isPaused = true
    }

    fun resume() {
        isPaused = false
    }

    private fun initPoseLandmarker() {
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("pose_landmarker_lite.task")
            .build()

        val options = PoseLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.IMAGE)
            .setNumPoses(1)
            .setMinPoseDetectionConfidence(CONF_MIN)
            .setMinPosePresenceConfidence(CONF_MIN)
            .setMinTrackingConfidence(CONF_MIN)
            .build()

        poseLandmarker = PoseLandmarker.createFromOptions(context, options)
    }

    private fun processFrame(imageProxy: ImageProxy, onEvent: (Map<String, Any?>) -> Unit) {
        try {
            val bitmap = imageProxy.toBitmap()
            val mpImage = BitmapImageBuilder(bitmap).build()
            val result = poseLandmarker?.detect(mpImage)

            val gesture: String
            var confidence: Double? = null

            if (result != null && result.landmarks().isNotEmpty()) {
                val landmarks = result.landmarks()[0]

                // Landmarks: 11=left shoulder, 12=right shoulder, 15=left wrist, 16=right wrist
                val leftShoulder = landmarks[11]
                val rightShoulder = landmarks[12]
                val leftWrist = landmarks[15]
                val rightWrist = landmarks[16]

                // Check confidence
                val minVis = minOf(
                    leftShoulder.visibility().orElse(0f),
                    rightShoulder.visibility().orElse(0f),
                    leftWrist.visibility().orElse(0f),
                    rightWrist.visibility().orElse(0f)
                )

                if (minVis < CONF_MIN) {
                    gesture = "UNKNOWN"
                } else {
                    // Apply EMA smoothing
                    val sLeftShoulderY = ema(smoothedLeftShoulderY, leftShoulder.y())
                    val sRightShoulderY = ema(smoothedRightShoulderY, rightShoulder.y())
                    val sLeftWristY = ema(smoothedLeftWristY, leftWrist.y())
                    val sRightWristY = ema(smoothedRightWristY, rightWrist.y())

                    smoothedLeftShoulderY = sLeftShoulderY
                    smoothedRightShoulderY = sRightShoulderY
                    smoothedLeftWristY = sLeftWristY
                    smoothedRightWristY = sRightWristY

                    // Classify
                    gesture = classify(
                        sLeftShoulderY, sRightShoulderY,
                        sLeftWristY, sRightWristY
                    )
                    confidence = minVis.toDouble()
                }
            } else {
                gesture = "UNKNOWN"
            }

            val event = mutableMapOf<String, Any?>(
                "tMs" to SystemClock.elapsedRealtime(),
                "gesture" to gesture
            )
            if (confidence != null) {
                event["confidence"] = confidence
            }

            onEvent(event)
        } catch (e: Exception) {
            Log.e(TAG, "Frame processing error", e)
        } finally {
            imageProxy.close()
            isProcessing = false
        }
    }

    private fun classify(
        leftShoulderY: Float, rightShoulderY: Float,
        leftWristY: Float, rightWristY: Float
    ): String {
        val armsUp = leftWristY < leftShoulderY - MARGIN_Y &&
                rightWristY < rightShoulderY - MARGIN_Y

        val armsDown = leftWristY > leftShoulderY + MARGIN_Y &&
                rightWristY > rightShoulderY + MARGIN_Y

        return when {
            armsUp -> "ARMS_UP"
            armsDown -> "ARMS_DOWN"
            else -> "UNKNOWN"
        }
    }

    private fun ema(previous: Float?, current: Float): Float {
        return if (previous == null) {
            current
        } else {
            EMA_ALPHA * current + (1 - EMA_ALPHA) * previous
        }
    }

    private fun resetSmoothing() {
        smoothedLeftShoulderY = null
        smoothedRightShoulderY = null
        smoothedLeftWristY = null
        smoothedRightWristY = null
    }
}
