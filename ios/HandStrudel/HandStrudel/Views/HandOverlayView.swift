import SwiftUI

struct HandOverlayView: UIViewRepresentable {
    let handsState: HandsState
    var videoAspect: CGFloat = 0.75

    func makeUIView(context: Context) -> HandCanvasView {
        let view = HandCanvasView()
        view.backgroundColor = .clear
        view.isOpaque = false
        return view
    }

    func updateUIView(_ uiView: HandCanvasView, context: Context) {
        uiView.videoAspect = videoAspect
        uiView.updateHands(handsState)
    }
}

// A single trail point with timestamp
private struct TrailPoint {
    let position: CGPoint  // normalized Vision coords
    let timestamp: TimeInterval
}

class HandCanvasView: UIView {
    var handsState = HandsState()
    var videoAspect: CGFloat = 0.75

    // Motion trails — fixed-size ring buffers per tracked point
    private var trails: [String: [TrailPoint]] = [:]
    private var trailWriteIdx: [String: Int] = [:]
    private let trailDuration: TimeInterval = 0.8
    private let maxTrailPoints = 48  // ~0.8s at 60fps
    private let trackedPoints = [0, 4, 8, 12, 16, 20]

    private let connections: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 4),
        (0, 5), (5, 6), (6, 7), (7, 8),
        (0, 9), (9, 10), (10, 11), (11, 12),
        (0, 13), (13, 14), (14, 15), (15, 16),
        (0, 17), (17, 18), (18, 19), (19, 20),
        (5, 9), (9, 13), (13, 17),
    ]

    func updateHands(_ hands: HandsState) {
        handsState = hands
        let now = CACurrentMediaTime()

        // Record trail points using ring buffer (no pruning needed)
        for (side, hand) in [("left", hands.left), ("right", hands.right)] {
            guard let hand else { continue }
            for idx in trackedPoints where idx < hand.landmarks.count {
                let key = "\(side)_\(idx)"
                let lm = hand.landmarks[idx]
                let pt = TrailPoint(position: CGPoint(x: lm.x, y: lm.y), timestamp: now)

                if trails[key] == nil {
                    trails[key] = Array(repeating: pt, count: maxTrailPoints)
                    trailWriteIdx[key] = 0
                }
                let writePos = trailWriteIdx[key] ?? 0
                trails[key]?[writePos] = pt
                trailWriteIdx[key] = (writePos + 1) % maxTrailPoints
            }
        }

        setNeedsDisplay()
    }

    private func visionToScreen(vx: CGFloat, vy: CGFloat, W: CGFloat, H: CGFloat) -> CGPoint {
        let screenAspect = W / H
        if videoAspect > screenAspect {
            let visibleFrac = screenAspect / videoAspect
            let offset = (1 - visibleFrac) / 2
            return CGPoint(x: (vx - offset) / visibleFrac * W, y: vy * H)
        } else {
            let visibleFrac = videoAspect / screenAspect
            let offset = (1 - visibleFrac) / 2
            return CGPoint(x: vx * W, y: (vy - offset) / visibleFrac * H)
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let W = bounds.width
        let H = bounds.height
        let now = CACurrentMediaTime()

        // Draw motion trails first (behind hands)
        drawTrails(ctx: ctx, side: "left",
                   color: UIColor(red: 0, green: 1, blue: 0.62, alpha: 1), W: W, H: H, now: now)
        drawTrails(ctx: ctx, side: "right",
                   color: UIColor(red: 1, green: 0.18, blue: 0.42, alpha: 1), W: W, H: H, now: now)

        // Draw hands on top
        if let left = handsState.left {
            drawHand(ctx: ctx, landmarks: left.landmarks,
                     color: UIColor(red: 0, green: 1, blue: 0.62, alpha: 1), W: W, H: H)
        }
        if let right = handsState.right {
            drawHand(ctx: ctx, landmarks: right.landmarks,
                     color: UIColor(red: 1, green: 0.18, blue: 0.42, alpha: 1), W: W, H: H)
        }
    }

    // MARK: - Motion Trails

    private func drawTrails(ctx: CGContext, side: String, color: UIColor, W: CGFloat, H: CGFloat, now: TimeInterval) {
        for idx in trackedPoints {
            let key = "\(side)_\(idx)"
            guard let points = trails[key], points.count >= 2 else { continue }

            // Fingertips get thicker, brighter trails
            let isTip = idx != 0
            let baseWidth: CGFloat = isTip ? 3.0 : 2.0

            ctx.saveGState()

            // Draw trail as connected line segments with fading opacity
            for i in 1..<points.count {
                let p0 = visionToScreen(vx: points[i-1].position.x, vy: points[i-1].position.y, W: W, H: H)
                let p1 = visionToScreen(vx: points[i].position.x, vy: points[i].position.y, W: W, H: H)

                // Age-based fade: newer = brighter
                let age = now - points[i].timestamp
                let fade = CGFloat(max(0, 1 - age / trailDuration))
                let alpha = fade * (isTip ? 0.6 : 0.3)

                if alpha < 0.01 { continue }

                // Width tapers with age
                let width = baseWidth * fade

                ctx.setStrokeColor(color.withAlphaComponent(alpha).cgColor)
                ctx.setLineWidth(width)
                ctx.setLineCap(.round)

                // Glow on fingertip trails
                if isTip && fade > 0.3 {
                    ctx.setShadow(offset: .zero, blur: 6 * fade, color: color.withAlphaComponent(alpha * 0.5).cgColor)
                }

                ctx.beginPath()
                ctx.move(to: p0)
                ctx.addLine(to: p1)
                ctx.strokePath()
            }

            ctx.restoreGState()
        }
    }

    // MARK: - Hand Drawing

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
            ctx.move(to: pt(a))
            ctx.addLine(to: pt(b))
        }
        ctx.strokePath()
        ctx.restoreGState()

        // Sharp lines
        ctx.setStrokeColor(color.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(1.5)
        ctx.beginPath()
        for (a, b) in connections {
            guard a < landmarks.count && b < landmarks.count else { continue }
            ctx.move(to: pt(a))
            ctx.addLine(to: pt(b))
        }
        ctx.strokePath()

        // Wrist dot
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
