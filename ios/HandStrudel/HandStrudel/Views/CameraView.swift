import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    /// Observed so the view re-evaluates when `isRunning` flips on after the
    /// user grants camera permission. Without this the first-launch flow leaves
    /// the screen black: the preview layer is created *after* `makeUIView`
    /// runs, and SwiftUI never re-invokes `updateUIView` unless something it's
    /// tracking on the view changes.
    @ObservedObject var handTracker: HandTrackingManager

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.backgroundColor = .black
        attachPreviewLayer(to: view)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        // First-launch: the preview layer wasn't available when `makeUIView`
        // ran (permission dialog hadn't resolved yet). Now that the camera
        // session is up, attach it.
        if uiView.previewLayer == nil {
            attachPreviewLayer(to: uiView)
        }
        uiView.previewLayer?.frame = uiView.bounds
    }

    private func attachPreviewLayer(to view: CameraPreviewView) {
        guard let previewLayer = handTracker.previewLayer else { return }
        view.previewLayer = previewLayer
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }
}

class CameraPreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
