import SwiftUI
import AVFoundation

@main
struct HandStrudelApp: App {
    init() {
        // Configure audio session for playback
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
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
