import AVFoundation
import UIKit
import MediaPipeTasksVision

/// Handles camera capture, MediaPipe Pose detection, gesture classification,
/// EMA smoothing, and emitting GestureEvents to Flutter on iOS.
class PoseGestureDetector: NSObject {

    private static let marginY: Float = 0.05
    private static let confMin: Float = 0.5
    private static let emaAlpha: Float = 0.3

    private var captureSession: AVCaptureSession?
    private var poseLandmarker: PoseLandmarker?
    private var onEvent: (([String: Any?]) -> Void)?
    private var isProcessing = false

    // EMA smoothed Y values
    private var smoothedLeftShoulderY: Float?
    private var smoothedRightShoulderY: Float?
    private var smoothedLeftWristY: Float?
    private var smoothedRightWristY: Float?

    private let processingQueue = DispatchQueue(label: "com.hangboard.pose.processing")

    func start(frontCamera: Bool, onEvent: @escaping ([String: Any?]) -> Void) throws {
        self.onEvent = onEvent
        try initPoseLandmarker()
        try setupCamera(frontCamera: frontCamera)
    }

    func stop() {
        captureSession?.stopRunning()
        captureSession = nil
        poseLandmarker = nil
        resetSmoothing()
    }

    private func initPoseLandmarker() throws {
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = Bundle.main.path(
            forResource: "pose_landmarker_lite",
            ofType: "task"
        ) ?? ""
        options.runningMode = .image
        options.numPoses = 1
        options.minPoseDetectionConfidence = PoseGestureDetector.confMin
        options.minPosePresenceConfidence = PoseGestureDetector.confMin
        options.minTrackingConfidence = PoseGestureDetector.confMin

        poseLandmarker = try PoseLandmarker(options: options)
    }

    private func setupCamera(frontCamera: Bool) throws {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        let position: AVCaptureDevice.Position = frontCamera ? .front : .back
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else {
            throw NSError(domain: "PoseGestureDetector", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Camera not available"])
        }

        let input = try AVCaptureDeviceInput(device: device)
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: processingQueue)
        output.alwaysDiscardsLateVideoFrames = true
        session.addOutput(output)

        captureSession = session
        session.startRunning()
    }

    private func classify(
        leftShoulderY: Float, rightShoulderY: Float,
        leftWristY: Float, rightWristY: Float
    ) -> String {
        let armsUp = leftWristY < leftShoulderY - PoseGestureDetector.marginY &&
            rightWristY < rightShoulderY - PoseGestureDetector.marginY

        let armsDown = leftWristY > leftShoulderY + PoseGestureDetector.marginY &&
            rightWristY > rightShoulderY + PoseGestureDetector.marginY

        if armsUp { return "ARMS_UP" }
        if armsDown { return "ARMS_DOWN" }
        return "UNKNOWN"
    }

    private func ema(previous: Float?, current: Float) -> Float {
        guard let prev = previous else { return current }
        return PoseGestureDetector.emaAlpha * current + (1 - PoseGestureDetector.emaAlpha) * prev
    }

    private func resetSmoothing() {
        smoothedLeftShoulderY = nil
        smoothedRightShoulderY = nil
        smoothedLeftWristY = nil
        smoothedRightWristY = nil
    }
}

extension PoseGestureDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !isProcessing else { return }
        isProcessing = true

        defer { isProcessing = false }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)

        guard let mpImage = try? MPImage(uiImage: uiImage) else { return }

        guard let result = try? poseLandmarker?.detect(image: mpImage),
              let landmarks = result.landmarks.first,
              landmarks.count > 16 else {
            onEvent?(["tMs": Int(ProcessInfo.processInfo.systemUptime * 1000),
                      "gesture": "UNKNOWN"])
            return
        }

        let leftShoulder = landmarks[11]
        let rightShoulder = landmarks[12]
        let leftWrist = landmarks[15]
        let rightWrist = landmarks[16]

        // Check confidence
        let minVis = min(
            leftShoulder.visibility?.floatValue ?? 0,
            rightShoulder.visibility?.floatValue ?? 0,
            leftWrist.visibility?.floatValue ?? 0,
            rightWrist.visibility?.floatValue ?? 0
        )

        var gesture: String
        var confidence: Double?

        if minVis < PoseGestureDetector.confMin {
            gesture = "UNKNOWN"
        } else {
            // Apply EMA
            let sLeftShoulderY = ema(previous: smoothedLeftShoulderY, current: leftShoulder.y)
            let sRightShoulderY = ema(previous: smoothedRightShoulderY, current: rightShoulder.y)
            let sLeftWristY = ema(previous: smoothedLeftWristY, current: leftWrist.y)
            let sRightWristY = ema(previous: smoothedRightWristY, current: rightWrist.y)

            smoothedLeftShoulderY = sLeftShoulderY
            smoothedRightShoulderY = sRightShoulderY
            smoothedLeftWristY = sLeftWristY
            smoothedRightWristY = sRightWristY

            gesture = classify(
                leftShoulderY: sLeftShoulderY,
                rightShoulderY: sRightShoulderY,
                leftWristY: sLeftWristY,
                rightWristY: sRightWristY
            )
            confidence = Double(minVis)
        }

        var event: [String: Any?] = [
            "tMs": Int(ProcessInfo.processInfo.systemUptime * 1000),
            "gesture": gesture
        ]
        if let conf = confidence {
            event["confidence"] = conf
        }
        onEvent?(event)
    }
}
