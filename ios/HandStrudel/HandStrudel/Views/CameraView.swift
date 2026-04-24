import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    let handTracker: HandTrackingManager

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.backgroundColor = .black
        if let previewLayer = handTracker.previewLayer {
            view.previewLayer = previewLayer
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.previewLayer?.frame = uiView.bounds
    }
}

class CameraPreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
