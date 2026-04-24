import SwiftUI

struct HeaderView: View {
    let status: String
    let beat: Int
    let bpm: Double

    var body: some View {
        HStack(spacing: 8) {
            // Beat dots
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i == beat ? (i % 2 == 0 ? Color.green : Color.pink) : Color.white.opacity(0.2))
                        .frame(width: 8, height: 8)
                        .animation(.easeOut(duration: 0.08), value: beat)
                }
            }

            Text(status)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)

            Spacer()

            Text("\(Int(bpm.rounded())) bpm")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color.black.opacity(0.7))
    }
}
