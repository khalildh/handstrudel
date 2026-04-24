import SwiftUI

struct HandOverlayView: UIViewRepresentable {
    let handsState: HandsState

    func makeUIView(context: Context) -> HandCanvasView {
        let view = HandCanvasView()
        view.backgroundColor = .clear
        view.isOpaque = false
        return view
    }

    func updateUIView(_ uiView: HandCanvasView, context: Context) {
        uiView.handsState = handsState
        uiView.setNeedsDisplay()
    }
}

class HandCanvasView: UIView {
    var handsState = HandsState()

    private let connections: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 4),
        (0, 5), (5, 6), (6, 7), (7, 8),
        (0, 9), (9, 10), (10, 11), (11, 12),
        (0, 13), (13, 14), (14, 15), (15, 16),
        (0, 17), (17, 18), (18, 19), (19, 20),
        (5, 9), (9, 13), (13, 17),
    ]

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
        let x = { (i: Int) -> CGFloat in CGFloat(landmarks[i].x) * W }
        let y = { (i: Int) -> CGFloat in CGFloat(landmarks[i].y) * H }

        // Glow layer (wider, more transparent)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 12, color: color.withAlphaComponent(0.5).cgColor)
        ctx.setStrokeColor(color.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(4)
        ctx.beginPath()
        for (a, b) in connections {
            guard a < landmarks.count && b < landmarks.count else { continue }
            ctx.move(to: CGPoint(x: x(a), y: y(a)))
            ctx.addLine(to: CGPoint(x: x(b), y: y(b)))
        }
        ctx.strokePath()
        ctx.restoreGState()

        // Sharp lines on top
        ctx.setStrokeColor(color.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(1.5)
        ctx.beginPath()
        for (a, b) in connections {
            guard a < landmarks.count && b < landmarks.count else { continue }
            ctx.move(to: CGPoint(x: x(a), y: y(a)))
            ctx.addLine(to: CGPoint(x: x(b), y: y(b)))
        }
        ctx.strokePath()

        // Wrist dot with glow
        if !landmarks.isEmpty {
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 10, color: color.cgColor)
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: CGRect(x: x(0) - 6, y: y(0) - 6, width: 12, height: 12))
            ctx.restoreGState()
        }

        // Fingertip dots (tips = 4, 8, 12, 16, 20)
        let tips = [4, 8, 12, 16, 20]
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 8, color: color.cgColor)
        ctx.setFillColor(color.withAlphaComponent(0.9).cgColor)
        for i in tips where i < landmarks.count {
            ctx.fillEllipse(in: CGRect(x: x(i) - 4, y: y(i) - 4, width: 8, height: 8))
        }
        ctx.restoreGState()

        // Other landmarks (subtle)
        ctx.setFillColor(color.withAlphaComponent(0.3).cgColor)
        for i in 1..<landmarks.count where !tips.contains(i) && i != 0 {
            ctx.fillEllipse(in: CGRect(x: x(i) - 2, y: y(i) - 2, width: 4, height: 4))
        }
    }
}
