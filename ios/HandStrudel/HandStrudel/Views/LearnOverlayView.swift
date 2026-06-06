import SwiftUI

struct LearnOverlayView: View {
    let noteCount: Int
    let scaleNotes: [Int]
    let visibleNotes: [LearnModeManager.VisibleNote]
    let hitEffects: [LearnModeManager.HitEffect]
    let score: LearnScore
    let songComplete: Bool
    let songName: String
    let leftPinchX: Double?
    let leftPinchY: Double?
    let rightPinchX: Double?
    let rightPinchY: Double?
    let leftPinching: Bool
    let rightPinching: Bool
    let videoAspect: CGFloat
    let countdownValue: Int
    let isCountingDown: Bool
    var onPlayAgain: () -> Void
    var onPickSong: () -> Void

    var body: some View {
        GeometryReader { geo in
            let topPad = geo.size.height * 0.15
            let bottomPad = geo.size.height * 0.20
            let usableHeight = geo.size.height - topPad - bottomPad
            let laneHeight = usableHeight / CGFloat(max(1, noteCount))
            let hitLineX = geo.size.width * 0.25

            // Aspect fill correction (same as grid overlay)
            let scrAspect = geo.size.width / geo.size.height
            let correctedY: (Double) -> CGFloat = { vy in
                if videoAspect > scrAspect {
                    return CGFloat(vy) * geo.size.height
                } else {
                    let vis = videoAspect / scrAspect
                    let off = (1 - vis) / 2
                    return (CGFloat(vy) - off) / vis * geo.size.height
                }
            }
            let correctedX: (Double) -> CGFloat = { vx in
                if videoAspect > scrAspect {
                    let vis = scrAspect / videoAspect
                    let off = (1 - vis) / 2
                    return (CGFloat(vx) - off) / vis * geo.size.width
                } else {
                    return CGFloat(vx) * geo.size.width
                }
            }

            let leftLane: Int? = leftPinchY.map { py in
                let screenY = correctedY(py) - topPad
                return max(0, min(noteCount - 1, Int(screenY / laneHeight)))
            }
            let rightLane: Int? = rightPinchY.map { py in
                let screenY = correctedY(py) - topPad
                return max(0, min(noteCount - 1, Int(screenY / laneHeight)))
            }

            ZStack {
                // MARK: - Lane Backgrounds
                VStack(spacing: 0) {
                    Spacer().frame(height: topPad)

                    ForEach(0..<noteCount, id: \.self) { i in
                        let noteIdx = noteCount - 1 - i
                        let isEven = i % 2 == 0
                        let isLeftHere = leftLane == i
                        let isRightHere = rightLane == i

                        ZStack {
                            Rectangle()
                                .fill(
                                    isLeftHere && leftPinching ? Color.green.opacity(0.2)
                                    : isRightHere && rightPinching ? Color.pink.opacity(0.2)
                                    : isLeftHere ? Color.green.opacity(0.08)
                                    : isRightHere ? Color.pink.opacity(0.08)
                                    : Color.white.opacity(isEven ? 0.03 : 0.0)
                                )

                            // Lane label on left margin
                            HStack {
                                if noteIdx < scaleNotes.count {
                                    Text(midiNoteName(scaleNotes[noteIdx]))
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.4))
                                        .padding(.leading, 6)
                                }
                                Spacer()
                            }

                            // Lane divider
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 0.5)
                            }
                        }
                        .frame(height: laneHeight)
                    }

                    Spacer()
                }

                // MARK: - Hit Line (vertical glowing cyan line)
                Rectangle()
                    .fill(Color.cyan)
                    .frame(width: 2, height: usableHeight)
                    .position(x: hitLineX, y: topPad + usableHeight / 2)
                    .shadow(color: .cyan.opacity(0.6), radius: 8)
                    .shadow(color: .cyan.opacity(0.3), radius: 16)

                // MARK: - Scrolling Note Capsules
                ForEach(visibleNotes) { note in
                    let visualRow = CGFloat(noteCount - 1 - note.laneIndex)
                    let laneY = topPad + visualRow * laneHeight + laneHeight / 2
                    let noteX = note.xFraction * geo.size.width
                    let noteWidth = max(30, note.widthFraction * geo.size.width)
                    let noteHeight = laneHeight * 0.7

                    RoundedRectangle(cornerRadius: 6)
                        .fill(noteFillColor(note.state))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(noteBorderColor(note.state), lineWidth: note.state == .upcoming ? 1 : 0)
                        )
                        .frame(width: noteWidth, height: noteHeight)
                        .position(x: noteX + noteWidth / 2, y: laneY)
                        .opacity(note.state == .missed ? 0.5 : 1.0)
                }

                // MARK: - Hit Effects (expanding glow at hit line)
                ForEach(hitEffects) { effect in
                    let visualRow = CGFloat(noteCount - 1 - effect.laneIndex)
                    let effectY = topPad + visualRow * laneHeight + laneHeight / 2

                    HitEffectView(
                        type: effect.type,
                        x: hitLineX,
                        y: effectY,
                        laneHeight: laneHeight
                    )
                }

                // MARK: - Hand Position Indicators (vertical lines)
                if let px = leftPinchX {
                    let handX = correctedX(px)
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: leftPinching ? 2 : 1, height: usableHeight)
                        .position(x: handX, y: topPad + usableHeight / 2)
                        .opacity(leftPinching ? 0.7 : 0.25)
                        .shadow(color: .green.opacity(leftPinching ? 0.5 : 0), radius: 6)
                }
                if let px = rightPinchX {
                    let handX = correctedX(px)
                    Rectangle()
                        .fill(Color.pink)
                        .frame(width: rightPinching ? 2 : 1, height: usableHeight)
                        .position(x: handX, y: topPad + usableHeight / 2)
                        .opacity(rightPinching ? 0.7 : 0.25)
                        .shadow(color: .pink.opacity(rightPinching ? 0.5 : 0), radius: 6)
                }

                // MARK: - Score HUD (top-right corner)
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text("\(score.perfectHits + score.goodHits)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.system(size: 10))
                                .foregroundColor(.cyan)
                            Text("\(Int(score.accuracy * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }

                        if score.currentStreak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                                Text("\(score.currentStreak)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 16)
                .padding(.top, topPad + 8)

                // MARK: - Countdown
                if isCountingDown && countdownValue > 0 {
                    Text("\(countdownValue)")
                        .font(.system(size: 120, weight: .black))
                        .foregroundColor(.white)
                        .shadow(color: .cyan, radius: 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.easeOut(duration: 0.3), value: countdownValue)
                }

                // MARK: - Song Complete Overlay
                if songComplete {
                    SongCompleteCard(
                        songName: songName,
                        score: score,
                        onPlayAgain: onPlayAgain,
                        onPickSong: onPickSong
                    )
                }
            }
        }
        .allowsHitTesting(songComplete)
    }

    // MARK: - Note Colors

    private func noteFillColor(_ state: LearnModeManager.NoteState) -> Color {
        switch state {
        case .upcoming:   return .cyan.opacity(0.5)
        case .active:     return .cyan.opacity(0.8)
        case .hitPerfect: return .green
        case .hitGood:    return .yellow
        case .missed:     return .red.opacity(0.3)
        }
    }

    private func noteBorderColor(_ state: LearnModeManager.NoteState) -> Color {
        switch state {
        case .upcoming: return .cyan.opacity(0.7)
        default:        return .clear
        }
    }
}

// MARK: - Hit Effect View

private struct HitEffectView: View {
    let type: LearnModeManager.NoteState
    let x: CGFloat
    let y: CGFloat
    let laneHeight: CGFloat

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0

    private var effectColor: Color {
        switch type {
        case .hitPerfect: return .green
        case .hitGood:    return .yellow
        case .missed:     return .red
        default:          return .clear
        }
    }

    var body: some View {
        Circle()
            .fill(effectColor.opacity(0.4))
            .frame(width: laneHeight * 1.5, height: laneHeight * 1.5)
            .overlay(
                Circle()
                    .stroke(effectColor, lineWidth: 2)
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .position(x: x, y: y)
            .shadow(color: effectColor.opacity(0.6), radius: 12)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.5
                    opacity = 0
                }
            }
    }
}

// MARK: - Song Complete Card

private struct SongCompleteCard: View {
    let songName: String
    let score: LearnScore
    let onPlayAgain: () -> Void
    let onPickSong: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Song name
            Text(songName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            // Accuracy (large)
            Text("\(Int(score.accuracy * 100))%")
                .font(.system(size: 56, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: accuracyGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("ACCURACY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(2)

            // Score breakdown
            HStack(spacing: 24) {
                scoreColumn(value: score.perfectHits, label: "PERFECT", color: .green)
                scoreColumn(value: score.goodHits, label: "GOOD", color: .yellow)
                scoreColumn(value: score.misses, label: "MISS", color: .red)
            }
            .padding(.top, 4)

            // Best streak
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                Text("Best Streak: \(score.bestStreak)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }

            // Buttons
            VStack(spacing: 10) {
                Button(action: onPlayAgain) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [.green, Color(red: 0.0, green: 0.8, blue: 0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                }

                Button(action: onPickSong) {
                    Text("PICK SONG")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .cornerRadius(12)
                }
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 30)
        .padding(.horizontal, 32)
    }

    private var accuracyGradient: [Color] {
        if score.accuracy >= 0.9 { return [.green, .cyan] }
        if score.accuracy >= 0.7 { return [.yellow, .green] }
        return [.red, .orange]
    }

    private func scoreColumn(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1)
        }
    }
}
