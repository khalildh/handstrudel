import AVFoundation
import Vision
import UIKit

struct HandLandmark {
    let x: Double
    let y: Double
    let z: Double
}

struct HandData {
    let x: Double
    let y: Double
    let spread: Double
    let pinch: Double
    let fist: Double
    let rotation: Double
    let thumbCurl: Double
    let indexCurl: Double
    let middleCurl: Double
    let ringCurl: Double
    let pinkyCurl: Double
    let landmarks: [HandLandmark]

    func value(for axisKey: String) -> Double? {
        switch axisKey {
        case "x": return x
        case "y": return y
        case "spread": return spread
        case "pinch": return pinch
        case "fist": return fist
        case "rotation": return rotation
        case "thumbCurl": return thumbCurl
        case "indexCurl": return indexCurl
        case "middleCurl": return middleCurl
        case "ringCurl": return ringCurl
        case "pinkyCurl": return pinkyCurl
        default: return nil
        }
    }
}

struct HandsState {
    var left: HandData?
    var right: HandData?
}

final class HandTrackingManager: NSObject, ObservableObject {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    private let processingQueue = DispatchQueue(label: "hand-tracking", qos: .userInteractive)

    var previewLayer: AVCaptureVideoPreviewLayer?
    var onHandsUpdate: ((HandsState) -> Void)?

    @Published var isRunning = false

    override init() {
        super.init()
        handPoseRequest.maximumHandCount = 2
    }

    func startSession() {
        guard !isRunning else { return }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // Mirror front camera
        if let connection = videoOutput.connection(with: .video) {
            connection.isVideoMirrored = true
        }

        captureSession.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        if let connection = layer.connection {
            connection.isVideoMirrored = true
        }
        self.previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.isRunning = true
            }
        }
    }

    func stopSession() {
        captureSession.stopRunning()
        isRunning = false
    }

    private func dist(_ a: HandLandmark, _ b: HandLandmark) -> Double {
        return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2) + pow(a.z - b.z, 2))
    }

    private func processObservation(_ observation: VNHumanHandPoseObservation) -> HandData? {
        guard let allPoints = try? observation.recognizedPoints(.all) else { return nil }

        // Map Vision joint names to landmark array (21 points)
        let jointOrder: [VNHumanHandPoseObservation.JointName] = [
            .wrist,
            .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip,
        ]

        var landmarks = [HandLandmark]()
        for joint in jointOrder {
            guard let point = allPoints[joint], point.confidence > 0.1 else {
                return nil
            }
            // Vision coordinates: origin bottom-left, y up. We want y inverted (top=0).
            landmarks.append(HandLandmark(x: point.location.x, y: 1 - point.location.y, z: 0))
        }

        let wristX = landmarks[0].x
        let wristY = landmarks[0].y

        // Spread: thumb tip to pinky tip distance
        let sp = sqrt(pow(landmarks[4].x - landmarks[20].x, 2) + pow(landmarks[4].y - landmarks[20].y, 2))
        let spread = min(1, sp * 2.8)

        // Finger curls (1 = extended)
        let thumbCurl  = min(1, dist(landmarks[4],  landmarks[2])  * 4)
        let indexCurl  = min(1, dist(landmarks[8],  landmarks[5])  * 4)
        let middleCurl = min(1, dist(landmarks[12], landmarks[9])  * 4)
        let ringCurl   = min(1, dist(landmarks[16], landmarks[13]) * 4)
        let pinkyCurl  = min(1, dist(landmarks[20], landmarks[17]) * 4)

        // Pinch: thumb tip close to index tip
        let pinch = max(0, min(1, 1 - dist(landmarks[4], landmarks[8]) * 5))

        // Fist: average of inverted curls
        let fist = 1 - (thumbCurl + indexCurl + middleCurl + ringCurl + pinkyCurl) / 5

        // Rotation: atan2 from wrist to middle MCP
        let dx = landmarks[9].x - landmarks[0].x
        let dy = landmarks[9].y - landmarks[0].y
        let rotation = (atan2(dy, dx) / .pi + 1) / 2

        return HandData(
            x: wristX, y: wristY, spread: spread,
            pinch: pinch, fist: fist, rotation: rotation,
            thumbCurl: thumbCurl, indexCurl: indexCurl, middleCurl: middleCurl,
            ringCurl: ringCurl, pinkyCurl: pinkyCurl,
            landmarks: landmarks
        )
    }
}

extension HandTrackingManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([handPoseRequest])

        var state = HandsState()

        guard let results = handPoseRequest.results else {
            onHandsUpdate?(state)
            return
        }

        for observation in results {
            guard let handData = processObservation(observation) else { continue }

            // Vision framework reports chirality — use it directly
            // Front camera is mirrored, so left hand appears as right visually
            let chirality = observation.chirality
            switch chirality {
            case .right:
                state.left = handData  // Right hand in mirror = user's left
            case .left:
                state.right = handData // Left hand in mirror = user's right
            default:
                if state.left == nil {
                    state.left = handData
                } else {
                    state.right = handData
                }
            }
        }

        onHandsUpdate?(state)
    }
}
