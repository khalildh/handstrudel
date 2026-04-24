import SwiftUI

struct HandOverlayView: UIViewRepresentable {
    let handsState: HandsState
    var videoAspect: CGFloat = 0.75 // default 3:4

    func makeUIView(context: Context) -> HandCanvasView {
        let view = HandCanvasView()
        view.backgroundColor = .clear
        view.isOpaque = false
        return view
    }

    func updateUIView(_ uiView: HandCanvasView, context: Context) {
        uiView.handsState = handsState
        uiView.videoAspect = videoAspect
        uiView.setNeedsDisplay()
    }
}

class HandCanvasView: UIView {
    var handsState = HandsState()
    var videoAspect: CGFloat = 0.75

    private let connections: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 4),
        (0, 5), (5, 6), (6, 7), (7, 8),
        (0, 9), (9, 10), (10, 11), (11, 12),
        (0, 13), (13, 14), (14, 15), (15, 16),
        (0, 17), (17, 18), (18, 19), (19, 20),
        (5, 9), (9, 13), (13, 17),
    ]

    /// Convert Vision normalized coordinates to screen coordinates,
    /// accounting for resizeAspectFill cropping.
    private func visionToScreen(vx: CGFloat, vy: CGFloat, W: CGFloat, H: CGFloat) -> CGPoint {
        let screenAspect = W / H

        var sx: CGFloat
        var sy: CGFloat

        if videoAspect > screenAspect {
            // Video is wider than screen — width is cropped, height fills
            let visibleFrac = screenAspect / videoAspect
            let offset = (1 - visibleFrac) / 2
            sx = (vx - offset) / visibleFrac * W
            sy = vy * H
        } else {
            // Video is taller than screen — height is cropped, width fills
            let visibleFrac = videoAspect / screenAspect
            let offset = (1 - visibleFrac) / 2
            sx = vx * W
            sy = (vy - offset) / visibleFrac * H
        }

        return CGPoint(x: sx, y: sy)
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let W = bounds.width
        let H = bounds.height

        if let left = handsState.left {
            drawHand(ctx: ctx, landmarks: left.landmarks,
                     color: UIColor(red: 0, green: 1, blue: 0.62, alpha: 1), W: W, H: H)
        }
        if let right = handsState.right {
            drawHand(ctx: ctx, landmarks: right.landmarks,
                     color: UIColor(red: 1, green: 0.18, blue: 0.42, alpha: 1), W: W, H: H)
        }
    }

    private func drawHand(ctx: CGContext, landmarks: [HandLandmark], color: UIColor, W: CGFloat, H: CGFloat) {
        let pt = { (i: Int) -> CGPoint in
            self.visionToScreen(vx: CGFloat(landmarks[i].x), vy: CGFloat(landmarks[i].y), W: W, H: H)
        }

        // Glow layer
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 12, color: color.withAlphaComponent(0.5).cgColor)
        ctx.setStrokeColor(color.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(4)
        ctx.beginPath()
        for (a, b) in connections {
            guard a < landmarks.count && b < landmarks.count else { continue }
            let pa = pt(a), pb = pt(b)
            ctx.move(to: pa)
            ctx.addLine(to: pb)
        }
        ctx.strokePath()
        ctx.restoreGState()

        // Sharp lines
        ctx.setStrokeColor(color.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(1.5)
        ctx.beginPath()
        for (a, b) in connections {
            guard a < landmarks.count && b < landmarks.count else { continue }
            let pa = pt(a), pb = pt(b)
            ctx.move(to: pa)
            ctx.addLine(to: pb)
        }
        ctx.strokePath()

        // Wrist dot with glow
        if !landmarks.isEmpty {
            let p = pt(0)
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 10, color: color.cgColor)
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12))
            ctx.restoreGState()
        }

        // Fingertip dots
        let tips = [4, 8, 12, 16, 20]
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 8, color: color.cgColor)
        ctx.setFillColor(color.withAlphaComponent(0.9).cgColor)
        for i in tips where i < landmarks.count {
            let p = pt(i)
            ctx.fillEllipse(in: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
        }
        ctx.restoreGState()

        // Other landmarks
        ctx.setFillColor(color.withAlphaComponent(0.3).cgColor)
        for i in 1..<landmarks.count where !tips.contains(i) && i != 0 {
            let p = pt(i)
            ctx.fillEllipse(in: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4))
        }
    }
}
