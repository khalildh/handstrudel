import SwiftUI
import AVFoundation
import RevenueCat

@main
struct HandStrudelApp: App {
    init() {
        // Configure audio session for playback + recording compatibility
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
        try? session.setActive(true)

        // Configure RevenueCat
        Purchases.logLevel = .error
        Purchases.configure(withAPIKey: "appl_AtnBabtuGJDXfdcQzvFykpDHfwf")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
