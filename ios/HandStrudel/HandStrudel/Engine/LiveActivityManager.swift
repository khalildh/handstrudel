import Foundation
import ActivityKit

// MARK: - Live Activity Manager
//
// Manages the Dynamic Island / Live Activity for HandStrudel.
//
// IMPORTANT: This file defines the ActivityAttributes and the manager that
// starts/updates/stops live activities. However, for Live Activities to
// actually appear on device, you also need:
//
// 1. A Widget Extension target (HandStrudelLiveActivity) added to the Xcode
//    project. The widget extension files are in:
//      - HandStrudelLiveActivity/HandStrudelLiveActivity.swift
//      - HandStrudelLiveActivity/HandStrudelLiveActivityBundle.swift
//
// 2. The widget extension target must be configured in project.yml (xcodegen)
//    or manually in Xcode with:
//      - type: app-extension
//      - platform: iOS
//      - Deployment target: iOS 16.2+
//      - NSSupportsLiveActivities = true in the main app's Info.plist
//      - The HandStrudelAttributes struct must be shared between the main app
//        and the widget extension (e.g., via a shared framework or by including
//        this file in both targets).
//
// 3. Add to the main app's Info.plist:
//      <key>NSSupportsLiveActivities</key>
//      <true/>
//

// Re-export the attributes so the main app target has access.
// The same struct is also defined in the widget extension target.
// In a production setup, this would live in a shared framework.

// Note: HandStrudelAttributes is defined in
// HandStrudelLiveActivity/HandStrudelLiveActivity.swift.
// We duplicate it here so the main app target can reference it without
// needing to import the widget extension module.

struct HandStrudelLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentNote: String
        var bpm: Int
        var mode: String
        var isRecording: Bool
    }
}

@available(iOS 16.2, *)
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<HandStrudelLiveActivityAttributes>?

    private init() {}

    // MARK: - Start Activity
    /// Call from EngineController.start() after isRunning = true

    func startActivity(note: String = "--", bpm: Int = 120, mode: String = "melodic", isRecording: Bool = false) {
        // End any existing activity first
        stopActivity()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Activities not enabled by user")
            return
        }

        let attributes = HandStrudelLiveActivityAttributes()
        let initialState = HandStrudelLiveActivityAttributes.ContentState(
            currentNote: note,
            bpm: bpm,
            mode: mode,
            isRecording: isRecording
        )

        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil  // No push updates; we update locally
            )
            currentActivity = activity
            print("[LiveActivity] Started: \(activity.id)")
        } catch {
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
        }
    }

    // MARK: - Update Activity
    /// Call from the UI timer (~15fps) in EngineController.startTimers()
    /// Only sends an update if the state actually changed.

    private var lastState: HandStrudelLiveActivityAttributes.ContentState?

    func updateActivity(note: String, bpm: Int, mode: String, isRecording: Bool) {
        guard let activity = currentActivity else { return }

        let newState = HandStrudelLiveActivityAttributes.ContentState(
            currentNote: note,
            bpm: bpm,
            mode: mode,
            isRecording: isRecording
        )

        // Skip update if nothing changed (Live Activity updates are rate-limited)
        guard newState != lastState else { return }
        lastState = newState

        let content = ActivityContent(state: newState, staleDate: nil)
        Task {
            await activity.update(content)
        }
    }

    // MARK: - Stop Activity
    /// Call from EngineController.stop()

    func stopActivity() {
        guard let activity = currentActivity else { return }

        let finalState = HandStrudelLiveActivityAttributes.ContentState(
            currentNote: "--",
            bpm: 0,
            mode: "stopped",
            isRecording: false
        )

        let content = ActivityContent(state: finalState, staleDate: nil)
        Task {
            await activity.end(content, dismissalPolicy: .immediate)
        }

        currentActivity = nil
        lastState = nil
        print("[LiveActivity] Stopped")
    }

    // MARK: - Helpers

    /// Convenience to derive mode string from EngineController state
    static func modeString(gridModeEnabled: Bool, drumModeEnabled: Bool, chordMode: Bool) -> String {
        if gridModeEnabled { return "grid" }
        if drumModeEnabled { return "drum" }
        if chordMode { return "chord" }
        return "melodic"
    }
}
