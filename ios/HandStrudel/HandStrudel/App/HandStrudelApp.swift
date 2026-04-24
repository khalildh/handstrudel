import SwiftUI
import AVFoundation

@main
struct HandStrudelApp: App {
    init() {
        // Configure audio session for playback + recording compatibility
        // .playAndRecord allows ReplayKit to capture app audio
        // .defaultToSpeaker routes audio to speaker instead of earpiece
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
        try? session.setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
        }
    }
}
