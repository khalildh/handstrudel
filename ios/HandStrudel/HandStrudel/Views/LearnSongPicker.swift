import SwiftUI

struct LearnSongPicker: View {
    let onSelect: (LearnSong) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("LEARN")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 20)

                // MARK: - Melodies Section
                sectionHeader("MELODIES")

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ], spacing: 12) {
                    ForEach(BUNDLED_SONGS) { song in
                        SongCard(song: song)
                            .onTapGesture {
                                onSelect(song)
                                dismiss()
                            }
                    }
                }

                // MARK: - Practice Section
                sectionHeader("PRACTICE")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        practiceButton(
                            label: "Ascending",
                            icon: "arrow.up",
                            generator: { LearnSong.ascending(noteCount: 10) }
                        )
                        practiceButton(
                            label: "Descending",
                            icon: "arrow.down",
                            generator: { LearnSong.descending(noteCount: 10) }
                        )
                        practiceButton(
                            label: "Arpeggio",
                            icon: "waveform.path",
                            generator: { LearnSong.arpeggio(noteCount: 14) }
                        )
                        practiceButton(
                            label: "Random",
                            icon: "dice",
                            generator: { LearnSong.random(noteCount: 12) }
                        )
                    }
                }

                // MARK: - Import Section
                sectionHeader("IMPORT")

                Button(action: {
                    // Placeholder: MIDI import not yet implemented
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 16))
                        Text("Import MIDI")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 24, height: 1)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.35))
                .tracking(2)
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 24, height: 1)
        }
    }

    private func practiceButton(label: String, icon: String, generator: @escaping () -> LearnSong) -> some View {
        Button(action: {
            let song = generator()
            onSelect(song)
            dismiss()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 90, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.15), Color.green.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Song Card

private struct SongCard: View {
    let song: LearnSong

    var body: some View {
        VStack(spacing: 8) {
            Text(song.emoji)
                .font(.system(size: 30))

            Text(song.name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)

            Text("\(Int(song.bpm)) BPM")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.green.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
