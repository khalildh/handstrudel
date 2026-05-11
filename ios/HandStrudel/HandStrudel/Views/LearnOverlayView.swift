import SwiftUI

struct LearnOverlayView: View {
    let noteCount: Int
    let scaleNotes: [Int]
    let visibleNotes: [LearnModeManager.VisibleNote]
    let hitEffects: [LearnModeManager.HitEffect]
    let score: LearnScore
    let songComplete: Bool
    let songName: String
    let leftLane: Int?
    let rightLane: Int?
    let leftPinching: Bool
    let rightPinching: Bool
    var onPlayAgain: () -> Void
    var onPickSong: () -> Void

    var body: some View {
        GeometryReader { geo in
            let topPad = geo.size.height * 0.15
            let bottomPad = geo.size.height * 0.20
            let usableHeight = geo.size.height - topPad - bottomPad
            let laneHeight = usableHeight / CGFloat(max(1, noteCount))
            let hitLineX = geo.size.width * 0.25

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
                    .frame(width: 2)
                    .position(x: hitLineX, y: topPad + usableHeight / 2)
                    .frame(height: usableHeight)
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
        .allowsHitTesting(songComplete) // only intercept taps when complete card is shown
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
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Accuracy (large)
            Text("\(Int(score.accuracy * 100))%")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: accuracyGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("ACCURACY")
                .font(.system(size: 11, weight: .bold, design: .rounded))
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
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }

            // Buttons
            VStack(spacing: 10) {
                Button(action: onPlayAgain) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 16, weight: .black, design: .rounded))
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
                        .font(.system(size: 14, weight: .bold, design: .rounded))
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
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1)
        }
    }
}
