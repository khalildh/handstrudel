import SwiftUI
import UIKit

// MARK: - Shake Detector

struct ShakeDetectorView: UIViewControllerRepresentable {
    let onShake: () -> Void

    class ShakeVC: UIViewController {
        var onShake: (() -> Void)?
        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake { onShake?() }
            super.motionEnded(motion, with: event)
        }
        override var canBecomeFirstResponder: Bool { true }
    }

    func makeUIViewController(context: Context) -> ShakeVC {
        let vc = ShakeVC()
        vc.onShake = onShake
        return vc
    }

    func updateUIViewController(_ vc: ShakeVC, context: Context) {
        vc.onShake = onShake
    }
}

// Wraps UIActivityViewController for sharing
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Wraps WKWebView for SwiftUI
struct WebViewContainer: UIViewRepresentable {
    let webView: UIView

    func makeUIView(context: Context) -> UIView {
        webView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
