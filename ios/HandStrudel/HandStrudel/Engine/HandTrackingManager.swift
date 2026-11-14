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
    let pinchX: Double  // midpoint of thumb tip + index tip
    let pinchY: Double
    let fist: Double
    let rotation: Double
    let thumbCurl: Double
    let indexCurl: Double
    let middleCurl: Double
    let ringCurl: Double
    let pinkyCurl: Double
    let landmarks: [HandLandmark]

    /// Count of extended fingers (curl > 0.6 = up)
    var fingersUp: Int {
        let threshold = 0.6
        var count = 0
        if thumbCurl > threshold { count += 1 }
        if indexCurl > threshold { count += 1 }
        if middleCurl > threshold { count += 1 }
        if ringCurl > threshold { count += 1 }
        if pinkyCurl > threshold { count += 1 }
        return count
    }

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
    @Published private(set) var cameraIssue: String?
    private var requestingCamera = false
    private var wantsCamera = false
    private var captureGeneration = 0
    private let captureQueue = DispatchQueue(label: "hand-tracking.capture", qos: .userInitiated)

    @Published var isRunning = false
    var videoWidth: CGFloat = 480
    var videoHeight: CGFloat = 640

    override init() {
        super.init()
        handPoseRequest.maximumHandCount = 2
        NotificationCenter.default.addObserver(self, selector: #selector(captureInterrupted),
                                               name: AVCaptureSession.wasInterruptedNotification, object: captureSession)
        NotificationCenter.default.addObserver(self, selector: #selector(captureRecovered),
                                               name: AVCaptureSession.interruptionEndedNotification, object: captureSession)
    }

    func startSession() {
        wantsCamera = true
        guard !isRunning, !requestingCamera else { return }
        cameraIssue = nil

        #if DEBUG
        // Promo-video mode: scripted hands instead of the camera.
        // startSession is always called from the main actor (EngineController).
        let usedDemo: Bool = MainActor.assumeIsolated {
            guard let demo = DemoDirector.shared else { return false }
            demo.startHands(tracker: self)
            return true
        }
        if usedDemo {
            isRunning = true
            return
        }
        #endif

        // Request camera permission first
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            requestingCamera = true
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.requestingCamera = false
                    guard self.wantsCamera else { return }
                    if granted { self.setupAndStart() }
                    else { self.cameraIssue = "Camera access is off. You can still play by touch." }
                }
            }
            return
        case .authorized:
            setupAndStart()
        case .denied, .restricted:
            cameraIssue = "Camera access is off. You can still play by touch."
            return
        @unknown default:
            cameraIssue = "Camera unavailable. You can still play by touch."
            return
        }
    }

    private func setupAndStart() {
        guard !isRunning else { return }

        if previewLayer != nil { runCapture(); return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            cameraIssue = "Camera unavailable. You can still play by touch."
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium
        if captureSession.isMultitaskingCameraAccessSupported {
            captureSession.isMultitaskingCameraAccessEnabled = true
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // Set video orientation to portrait and mirror for front camera
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }

        captureSession.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        if let connection = layer.connection {
            connection.videoOrientation = .portrait
        }
        self.previewLayer = layer

        runCapture()
    }

    private func runCapture() {
        requestingCamera = true
        captureGeneration += 1
        let generation = captureGeneration
        captureQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.startRunning()
            let running = self.captureSession.isRunning
            DispatchQueue.main.async {
                guard self.captureGeneration == generation else { return }
                self.requestingCamera = false
                guard self.wantsCamera else { return }
                self.isRunning = running
                self.cameraIssue = running ? nil : "Camera unavailable. You can still play by touch."
            }
        }
    }

    func stopSession() {
        wantsCamera = false
        captureGeneration += 1
        if AVCaptureDevice.authorizationStatus(for: .video) != .notDetermined {
            requestingCamera = false
        }
        captureQueue.async { [weak self] in self?.captureSession.stopRunning() }
        isRunning = false
    }

    @objc private func captureInterrupted(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.wantsCamera else { return }
            self.cameraIssue = "Camera in use. You can still play by touch."
            self.onHandsUpdate?(HandsState())
        }
    }

    @objc private func captureRecovered(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.wantsCamera else { return }
            self.cameraIssue = nil
        }
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
            // Vision: origin bottom-left, y up. Flip y so top=0.
            // x stays as-is since video output is already mirrored to match preview.
            landmarks.append(HandLandmark(x: point.location.x, y: 1 - point.location.y, z: 0))
        }

        return HandTrackingManager.makeHandData(landmarks: landmarks)
    }

    /// Derive every gesture axis from 21 normalized landmarks (top-left origin).
    /// Shared by Vision tracking and the DEBUG demo driver so both feed the
    /// engine identical data.
    static func makeHandData(landmarks: [HandLandmark]) -> HandData {
        func dist(_ a: HandLandmark, _ b: HandLandmark) -> Double {
            sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2) + pow(a.z - b.z, 2))
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

        // Fist: average of inverted curls (clamped 0-1)
        let fist = max(0, min(1, 1 - (thumbCurl + indexCurl + middleCurl + ringCurl + pinkyCurl) / 5))

        // Rotation: atan2 from wrist to middle MCP
        let dx = landmarks[9].x - landmarks[0].x
        let dy = landmarks[9].y - landmarks[0].y
        let rotation = (atan2(dy, dx) / .pi + 1) / 2

        // Pinch point: midpoint of thumb tip (4) and index tip (8)
        let pinchPointX = (landmarks[4].x + landmarks[8].x) / 2
        let pinchPointY = (landmarks[4].y + landmarks[8].y) / 2

        return HandData(
            x: wristX, y: wristY, spread: spread,
            pinch: pinch, pinchX: pinchPointX, pinchY: pinchPointY,
            fist: fist, rotation: rotation,
            thumbCurl: thumbCurl, indexCurl: indexCurl, middleCurl: middleCurl,
            ringCurl: ringCurl, pinkyCurl: pinkyCurl,
            landmarks: landmarks
        )
    }
}

extension HandTrackingManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Capture actual video dimensions (after rotation to portrait)
        let w = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let h = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        if w > 0 && h > 0 {
            videoWidth = w
            videoHeight = h
        }

        // Video output is set to .portrait + mirrored, so frames arrive correctly oriented
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([handPoseRequest])

        var state = HandsState()

        guard let results = handPoseRequest.results else {
            onHandsUpdate?(state)
            return
        }

        for observation in results {
            guard let handData = processObservation(observation) else { continue }

            // Video output is mirrored, so Vision's chirality is flipped:
            // Vision .left in mirrored frame = user's right hand, and vice versa.
            switch observation.chirality {
            case .left:
                state.right = handData
            case .right:
                state.left = handData
            @unknown default:
                break
            }
        }

        onHandsUpdate?(state)
    }
}

// MARK: - Promo-video demo driver (DEBUG only)

#if DEBUG
/// Drives the real app with scripted hands so promo videos can be produced
/// without a camera (e.g. in the iOS Simulator).
///
/// Activated by the `HANDSTRUDEL_DEMO_SCRIPT` environment variable (pass it via
/// `SIMCTL_CHILD_HANDSTRUDEL_DEMO_SCRIPT=… xcrun simctl launch …`). The value
/// is a JSON file path — absolute, or relative to the app's Documents folder.
/// Produced by `promo/` in the repo root; see `promo/README.md`.
///
/// Script keyframes are in **screen space** (0…1, top-left origin) and give
/// the *pinch point* (midpoint of thumb + index tips) — exactly what the
/// chord/melody wheel reads. The driver converts to camera space (undoing the
/// aspect-fill crop) and synthesizes a 21-point hand around that point.
///
/// While running it also records the SoundFont engine's output to
/// `Documents/demo_out/audio.caf` and writes `meta.json` with the wall-clock
/// time the script started, so the pipeline can sync audio to screen video.
@MainActor
final class DemoDirector {
    struct Keyframe: Decodable {
        let t: Double
        let x: Double
        let y: Double
        let pinch: Double
        let visible: Bool?
    }

    struct Script: Decodable {
        let name: String?
        let duration: Double
        let startDelay: Double?
        let instrument: String?
        let key: String?
        let scale: String?
        /// Chord progression id; defaults to "free" (all 7 diatonic chords,
        /// zone index == scale degree), which the promo composer assumes.
        let progression: String?
        let left: [Keyframe]
        let right: [Keyframe]
    }

    static let shared: DemoDirector? = DemoDirector.load()

    let script: Script
    let outputDir: URL
    private weak var tracker: HandTrackingManager?
    private var displayLink: CADisplayLink?
    private var startHost: CFTimeInterval = 0
    private var finished = false

    /// Set by ContentView so the director can reach the audio engine.
    var onBeginCapture: ((URL) -> Void)?
    var onEndCapture: (() -> Void)?

    private init(script: Script, outputDir: URL) {
        self.script = script
        self.outputDir = outputDir
    }

    private static func load() -> DemoDirector? {
        guard let raw = ProcessInfo.processInfo.environment["HANDSTRUDEL_DEMO_SCRIPT"],
              !raw.isEmpty else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = raw.hasPrefix("/") ? URL(fileURLWithPath: raw) : docs.appendingPathComponent(raw)
        do {
            let data = try Data(contentsOf: url)
            let script = try JSONDecoder().decode(Script.self, from: data)
            let out = docs.appendingPathComponent("demo_out", isDirectory: true)
            try? FileManager.default.removeItem(at: out)
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            print("[demo] loaded script '\(script.name ?? url.lastPathComponent)' duration=\(script.duration)s")
            return DemoDirector(script: script, outputDir: out)
        } catch {
            print("[demo] failed to load \(url.path): \(error)")
            return nil
        }
    }

    func startHands(tracker: HandTrackingManager) {
        self.tracker = tracker
        let delay = script.startDelay ?? 2.0
        // Empty hands until the script starts so the engine settles.
        tracker.onHandsUpdate?(HandsState())
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.begin()
        }
    }

    private func begin() {
        let audioURL = outputDir.appendingPathComponent("audio.caf")
        onBeginCapture?(audioURL)
        startHost = CACurrentMediaTime()
        let meta: [String: Any] = [
            "startEpoch": Date().timeIntervalSince1970,
            "duration": script.duration,
            "name": script.name ?? "",
        ]
        if let data = try? JSONSerialization.data(withJSONObject: meta, options: .prettyPrinted) {
            try? data.write(to: outputDir.appendingPathComponent("meta.json"))
        }
        let link = CADisplayLink(target: DemoLinkTarget { [weak self] in self?.tick() },
                                 selector: #selector(DemoLinkTarget.fire))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
        print("[demo] started")
    }

    private func tick() {
        guard let tracker, !finished else { return }
        let t = CACurrentMediaTime() - startHost
        if t >= script.duration {
            finished = true
            displayLink?.invalidate()
            displayLink = nil
            tracker.onHandsUpdate?(HandsState())
            // Let release tails ring out before closing the file.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.onEndCapture?()
                if let dir = self?.outputDir {
                    try? Data("done".utf8).write(to: dir.appendingPathComponent("done"))
                }
                print("[demo] finished")
            }
            return
        }
        let videoAspect = tracker.videoWidth / tracker.videoHeight
        let b = UIScreen.main.bounds
        let screenAspect = b.width / b.height
        var state = HandsState()
        state.left = hand(at: t, frames: script.left, isLeft: true,
                          videoAspect: videoAspect, screenAspect: screenAspect)
        state.right = hand(at: t, frames: script.right, isLeft: false,
                           videoAspect: videoAspect, screenAspect: screenAspect)
        tracker.onHandsUpdate?(state)
    }

    // MARK: Interpolation

    private struct Pose { var x: Double; var y: Double; var pinch: Double; var visible: Bool }

    private func pose(at t: Double, frames: [Keyframe]) -> Pose? {
        guard let first = frames.first else { return nil }
        if t <= first.t {
            return Pose(x: first.x, y: first.y, pinch: first.pinch, visible: first.visible ?? true)
        }
        for i in 0..<(frames.count - 1) {
            let a = frames[i], b = frames[i + 1]
            if t >= a.t && t < b.t {
                let u = (t - a.t) / max(1e-6, b.t - a.t)
                let s = u * u * (3 - 2 * u) // smoothstep
                return Pose(x: a.x + (b.x - a.x) * s,
                            y: a.y + (b.y - a.y) * s,
                            pinch: a.pinch + (b.pinch - a.pinch) * s,
                            visible: a.visible ?? true)
            }
        }
        let last = frames[frames.count - 1]
        return Pose(x: last.x, y: last.y, pinch: last.pinch, visible: last.visible ?? true)
    }

    // MARK: Synthetic hand

    /// Open-hand model, palm facing camera, fingers up, in camera-normalized
    /// units relative to the wrist. Thumb on +x (as a mirrored LEFT hand
    /// appears on screen); mirrored for the right hand.
    private static let model: [(Double, Double)] = [
        (0, 0),                                                          // wrist
        (0.035, -0.025), (0.065, -0.045), (0.088, -0.060), (0.100, -0.070), // thumb
        (0.025, -0.090), (0.028, -0.125), (0.030, -0.148), (0.031, -0.168), // index
        (0.000, -0.095), (0.000, -0.135), (0.000, -0.160), (0.000, -0.182), // middle
        (-0.022, -0.090), (-0.024, -0.125), (-0.026, -0.148), (-0.027, -0.165), // ring
        (-0.040, -0.078), (-0.047, -0.105), (-0.052, -0.122), (-0.055, -0.137), // pinky
    ]

    private func hand(at t: Double, frames: [Keyframe], isLeft: Bool,
                      videoAspect: CGFloat, screenAspect: CGFloat) -> HandData? {
        guard let p = pose(at: t, frames: frames), p.visible else { return nil }

        // Screen → camera x (undo aspect-fill horizontal crop).
        var camX = p.x
        if videoAspect > screenAspect {
            let visible = Double(screenAspect / videoAspect)
            camX = (1 - visible) / 2 + p.x * visible
        }
        let camY = p.y

        let side: Double = isLeft ? 1 : -1
        let scale = 0.95
        let pinch = max(0, min(1, p.pinch))
        // Gentle idle motion so the skeleton feels alive.
        let wobble = 0.004
        let phase = isLeft ? 0.0 : 1.7
        let wx = sin(t * 2.1 + phase) * wobble
        let wy = cos(t * 1.7 + phase) * wobble

        var pts = Self.model.map { ($0.0 * side * scale, $0.1 * scale) }
        // Pinch: bring thumb tip and index tip together around their midpoint.
        let thumbOpen = pts[4], indexOpen = pts[8]
        let mid = ((thumbOpen.0 + indexOpen.0) / 2, (thumbOpen.1 + indexOpen.1) / 2)
        let k = 1 - pinch
        pts[4] = (mid.0 + (thumbOpen.0 - mid.0) * k, mid.1 + (thumbOpen.1 - mid.1) * k)
        pts[8] = (mid.0 + (indexOpen.0 - mid.0) * k, mid.1 + (indexOpen.1 - mid.1) * k)
        // Drag the joints behind the tips partway so the fingers curl.
        for (j, tip, amt) in [(3, 4, 0.55), (7, 8, 0.6), (6, 8, 0.3)] {
            let open = Self.model[j]
            let o = (open.0 * side * scale, open.1 * scale)
            let target = pts[tip]
            pts[j] = (o.0 + (target.0 - o.0) * amt * pinch * 0.5,
                      o.1 + (target.1 - o.1) * amt * pinch * 0.5)
        }
        // Anchor so the pinch point (thumb/index midpoint) lands on the target.
        let anchor = ((pts[4].0 + pts[8].0) / 2, (pts[4].1 + pts[8].1) / 2)
        let landmarks = pts.map {
            HandLandmark(x: camX + $0.0 - anchor.0 + wx, y: camY + $0.1 - anchor.1 + wy, z: 0)
        }
        return HandTrackingManager.makeHandData(landmarks: landmarks)
    }
}

private final class DemoLinkTarget: NSObject {
    let callback: () -> Void
    init(_ callback: @escaping () -> Void) { self.callback = callback }
    @objc func fire() { callback() }
}
#endif
