import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    let handTracker: HandTrackingManager
    let handsState: HandsState

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        if let previewLayer = handTracker.previewLayer {
            previewLayer.frame = UIScreen.main.bounds
            view.layer.addSublayer(previewLayer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = handTracker.previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}
