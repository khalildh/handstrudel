import SwiftUI
import AVFoundation
import RevenueCat

@main
struct HandStrudelApp: App {
    init() {
        restoreInstrumentAudio()

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

func restoreInstrumentAudio() {
    let session = AVAudioSession.sharedInstance()
    do {
        // FaceTime can hold exclusive microphone access while allowing playback.
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    } catch {
        debugPrint("Instrument audio setup failed:", error)
    }
}
