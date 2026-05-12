import SwiftUI
import WatchConnectivity

// NOTE: This Watch app requires a separate "watchOS App" target in Xcode.
// In Xcode: File > New > Target > watchOS > App.
// Set the bundle ID to com.handstrudel.watchkitapp (or matching your team config).
// Add WatchConnectivity.framework to both the Watch target and the iOS target.
// Ensure the Watch target is added as a companion to the iOS app target.

@main
struct HandStrudelWatchApp: App {
    @StateObject private var connector = WatchConnector()

    var body: some Scene {
        WindowGroup {
            DrumPadView(connector: connector)
        }
    }
}
