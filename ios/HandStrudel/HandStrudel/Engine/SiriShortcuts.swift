import AppIntents

@available(iOS 16.0, *)
struct StartDreamyIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Dreamy Mode"
    static var description = IntentDescription("Open HandStrudel in Dreamy preset")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .siriStartPreset, object: "dreamy")
        }
        return .result()
    }
}

@available(iOS 16.0, *)
struct StartGrittyIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Gritty Mode"
    static var description = IntentDescription("Open HandStrudel in Gritty preset")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .siriStartPreset, object: "gritty")
        }
        return .result()
    }
}

@available(iOS 16.0, *)
struct StartGridModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Grid Mode"
    static var description = IntentDescription("Open HandStrudel in pinch-to-play Grid mode")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .siriStartMode, object: "grid")
        }
        return .result()
    }
}

@available(iOS 16.0, *)
struct StartDrumModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Drum Mode"
    static var description = IntentDescription("Open HandStrudel in air drumming mode")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .siriStartMode, object: "drums")
        }
        return .result()
    }
}

@available(iOS 16.0, *)
struct ToggleLoopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Loop Recording"
    static var description = IntentDescription("Start or stop loop recording in HandStrudel")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .toggleLoopRecording, object: nil)
        }
        return .result()
    }
}

@available(iOS 16.0, *)
struct HandStrudelSiriShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartDreamyIntent(),
            phrases: ["Start dreamy mode in \(.applicationName)", "Play dreamy in \(.applicationName)"],
            shortTitle: "Dreamy",
            systemImageName: "moon"
        )
        AppShortcut(
            intent: StartGrittyIntent(),
            phrases: ["Start gritty mode in \(.applicationName)", "Play gritty in \(.applicationName)"],
            shortTitle: "Gritty",
            systemImageName: "flame"
        )
        AppShortcut(
            intent: StartGridModeIntent(),
            phrases: ["Start grid mode in \(.applicationName)", "Play piano in \(.applicationName)"],
            shortTitle: "Grid Mode",
            systemImageName: "square.grid.3x3"
        )
        AppShortcut(
            intent: StartDrumModeIntent(),
            phrases: ["Start drums in \(.applicationName)", "Play drums in \(.applicationName)"],
            shortTitle: "Drums",
            systemImageName: "drum"
        )
        AppShortcut(
            intent: ToggleLoopRecordingIntent(),
            phrases: ["Record a loop in \(.applicationName)"],
            shortTitle: "Record Loop",
            systemImageName: "record.circle"
        )
    }
}

extension Notification.Name {
    static let siriStartPreset = Notification.Name("siriStartPreset")
    static let siriStartMode = Notification.Name("siriStartMode")
    static let toggleLoopRecording = Notification.Name("toggleLoopRecording")
}
