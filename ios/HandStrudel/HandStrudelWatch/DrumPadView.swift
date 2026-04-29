import SwiftUI

struct DrumPadView: View {
    @ObservedObject var connector: WatchConnector

    let pads: [(name: String, type: String, color: Color)] = [
        ("Kick", "kick", .red),
        ("Snare", "snare", .orange),
        ("Hat", "hihat", .cyan),
        ("Tom", "tom", .purple),
    ]

    var body: some View {
        VStack(spacing: 4) {
            Text("HandStrudel")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.green)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4)
            ], spacing: 4) {
                ForEach(pads, id: \.type) { pad in
                    Button(action: {
                        connector.sendDrumHit(pad.type)
                        WKInterfaceDevice.current().play(.click)
                    }) {
                        Text(pad.name)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(pad.color.opacity(0.3))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(4)
    }
}
