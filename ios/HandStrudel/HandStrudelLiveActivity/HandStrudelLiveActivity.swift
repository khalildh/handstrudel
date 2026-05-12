import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Attributes Definition

struct HandStrudelAttributes: ActivityAttributes {
    /// Static context that doesn't change during the activity
    public struct ContentState: Codable, Hashable {
        var currentNote: String   // e.g. "C4", "Dm7", "pinch to play"
        var bpm: Int              // current BPM
        var mode: String          // "melodic", "grid", "drum"
        var isRecording: Bool     // loop recording active
    }
}

// MARK: - Live Activity Widget

@available(iOS 16.2, *)
struct HandStrudelLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HandStrudelAttributes.self) { context in
            // Lock screen / notification banner expanded view
            HStack(spacing: 16) {
                // Left: app identity
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                    .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(context.state.currentNote)
                            .font(.title3.bold())
                            .foregroundColor(.white)

                        if context.state.isRecording {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text("REC")
                                .font(.caption2.bold())
                                .foregroundColor(.red)
                        }
                    }

                    HStack(spacing: 8) {
                        Label("\(context.state.bpm) BPM", systemImage: "metronome")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Text(context.state.mode)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.2, green: 0.9, blue: 0.4).opacity(0.2))
                            .cornerRadius(4)
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                    }
                }

                Spacer()

                // Right: waveform visualization hint
                Image(systemName: "waveform")
                    .font(.title3)
                    .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4).opacity(0.6))
            }
            .padding(16)
            .activityBackgroundTint(.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                        Text(context.state.currentNote)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4) {
                        if context.state.isRecording {
                            Circle()
                                .fill(.red)
                                .frame(width: 6, height: 6)
                        }
                        Text("\(context.state.bpm)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.gray)
                        Text("BPM")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.mode)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.2, green: 0.9, blue: 0.4).opacity(0.2))
                            .cornerRadius(6)
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))

                        Spacer()

                        Image(systemName: "waveform")
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4).opacity(0.5))
                    }
                }
            } compactLeading: {
                Image(systemName: "music.note")
                    .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
            } compactTrailing: {
                Text(context.state.currentNote)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } minimal: {
                Image(systemName: "music.note")
                    .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
            }
        }
    }
}
