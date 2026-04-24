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
            drawHand(ctx: ctx, landmarks: left.landmarks, color: UIColor(red: 0, green: 1, blue: 0.616, alpha: 1), W: W, H: H)
        }
        if let right = handsState.right {
            drawHand(ctx: ctx, landmarks: right.landmarks, color: UIColor(red: 1, green: 0.176, blue: 0.42, alpha: 1), W: W, H: H)
        }
    }

    private func drawHand(ctx: CGContext, landmarks: [HandLandmark], color: UIColor, W: CGFloat, H: CGFloat) {
        let x = { (i: Int) -> CGFloat in CGFloat(landmarks[i].x) * W }
        let y = { (i: Int) -> CGFloat in CGFloat(landmarks[i].y) * H }

        // Draw connections
        ctx.setStrokeColor(color.withAlphaComponent(0.33).cgColor)
        ctx.setLineWidth(1.5)
        ctx.beginPath()
        for (a, b) in connections {
            guard a < landmarks.count && b < landmarks.count else { continue }
            ctx.move(to: CGPoint(x: x(a), y: y(a)))
            ctx.addLine(to: CGPoint(x: x(b), y: y(b)))
        }
        ctx.strokePath()

        // Draw wrist dot
        if !landmarks.isEmpty {
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: CGRect(x: x(0) - 5, y: y(0) - 5, width: 10, height: 10))
        }

        // Draw other landmarks
        ctx.setFillColor(color.withAlphaComponent(0.67).cgColor)
        for i in 1..<landmarks.count {
            let r: CGFloat = i % 4 == 0 ? 3.5 : 2
            ctx.fillEllipse(in: CGRect(x: x(i) - r, y: y(i) - r, width: r * 2, height: r * 2))
        }
    }
}
