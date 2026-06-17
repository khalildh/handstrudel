import SwiftUI

// MARK: - The Weave
//
// HandStrudel's music made visible. Strudel patterns are living cycles — a
// loop continuously reshaped by your hands. The Weave renders that: layered,
// swirling rose-curves that orbit and breathe with the live musical
// parameters, composed over the camera so you see yourself weaving sound into
// image. It replaces the developer-facing code pill as the hero of the
// performance screen.
//
// Inputs are normalized 0...1 so the view stays decoupled from the engine:
//   hue        — pitch / accent color
//   energy     — volume → scale + intensity
//   space      — reverb → glow / softness
//   brightness — filter cutoff → line crispness
//   speed      — tempo → rotation rate
//   complexity — extra motion (crush/shape) → petal count + wobble

struct WeaveView: View {
    var hue: Double
    var energy: Double
    var space: Double
    var brightness: Double
    var speed: Double
    var complexity: Double = 0.5

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let base = min(size.width, size.height) * 0.30
                let rot = t * (0.06 + speed * 0.5)
                let petals = 2 + Int(round(complexity * 4))   // 2…6
                let layers = 3

                ctx.blendMode = .plusLighter

                for layer in 0..<layers {
                    let lp = Double(layer)
                    let phase = rot + lp * 0.7
                    let breathe = 0.85 + 0.15 * sin(t * (0.6 + speed * 0.8) + lp)

                    var path = Path()
                    let steps = 180
                    for i in 0...steps {
                        let th = Double(i) / Double(steps) * .pi * 2
                        // Rose curve r = cos(k·θ), warped over time into a woven swirl.
                        let petal = 0.55 + 0.45 * sin(Double(petals) * th + phase)
                        let wobble = 1 + complexity * 0.18 * sin(3 * th - rot * 1.3)
                        let rr = base * petal * wobble * breathe
                            * (0.8 + energy * 0.5)
                        let a = th + rot * 0.35
                        let x = center.x + CGFloat(cos(a) * rr)
                        let y = center.y + CGFloat(sin(a) * rr)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    path.closeSubpath()

                    let col = Color(
                        hue: (hue + lp * 0.05).truncatingRemainder(dividingBy: 1),
                        saturation: 0.72,
                        brightness: 1
                    )

                    // Soft outer glow (reverb opens it up).
                    var glow = ctx
                    glow.addFilter(.blur(radius: 4 + space * 22))
                    glow.opacity = 0.14 + energy * 0.22
                    glow.stroke(path, with: .color(col), lineWidth: 2 + brightness * 3)

                    // Crisp inner thread (filter brightness sharpens it).
                    var core = ctx
                    core.opacity = 0.30 + brightness * 0.30
                    core.stroke(path, with: .color(col), lineWidth: 1 + brightness * 1.2)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
