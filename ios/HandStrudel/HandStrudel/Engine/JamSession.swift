import Foundation
import GroupActivities
import Combine
import UIKit

// MARK: - Group Activity

struct HandStrudelActivity: GroupActivity {
    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "HandStrudel Jam"
        meta.subtitle = "Make music together"
        meta.type = .generic
        return meta
    }
}

// MARK: - Messages sent between participants

struct JamMessage: Codable {
    let senderId: String
    let senderName: String
    let event: JamEvent
    let timestamp: Double
}

enum JamEvent: Codable {
    case noteOn(midi: Int, waveform: String, velocity: Double)
    case noteOff(hand: String)
    case drumHit(hitType: String)
    case bpmChange(bpm: Double)
}

// MARK: - Jam Session Manager

@MainActor
final class JamSessionManager: ObservableObject {
    @Published var isActive = false
    @Published var isHost = false
    @Published var participants: [String] = []  // participant display names
    @Published var lastReceivedEvent: String = ""

    private var session: GroupSession<HandStrudelActivity>?
    private var messenger: GroupSessionMessenger?
    private var subscriptions = Set<AnyCancellable>()
    private var tasks = Set<Task<Void, Never>>()

    let deviceId = UUID().uuidString.prefix(8).lowercased()
    var deviceName: String { UIDevice.current.name }

    var onRemoteEvent: ((JamEvent) -> Void)?

    // MARK: - Start/Join Session

    func startSession() {
        let activity = HandStrudelActivity()
        Task {
            do {
                _ = try await activity.activate()
            } catch {
                debugPrint("Failed to activate activity:", error)
            }
        }

        // Listen for incoming sessions
        let task = Task {
            for await session in HandStrudelActivity.sessions() {
                await configureSession(session)
            }
        }
        tasks.insert(task)
    }

    private func configureSession(_ session: GroupSession<HandStrudelActivity>) async {
        self.session = session
        let messenger = GroupSessionMessenger(session: session)
        self.messenger = messenger

        // Track participants
        session.$activeParticipants
            .sink { [weak self] participants in
                self?.participants = participants.map { $0.id.description }
                self?.isActive = !participants.isEmpty
            }
            .store(in: &subscriptions)

        // Listen for messages
        let receiveTask = Task {
            for await (message, _) in messenger.messages(of: JamMessage.self) {
                handleRemoteMessage(message)
            }
        }
        tasks.insert(receiveTask)

        session.join()
        isActive = true
    }

    // MARK: - Send Events

    func sendEvent(_ event: JamEvent) {
        guard let messenger, isActive else { return }
        let message = JamMessage(
            senderId: String(deviceId),
            senderName: deviceName,
            event: event,
            timestamp: Date().timeIntervalSince1970
        )
        Task {
            do {
                try await messenger.send(message)
            } catch {
                debugPrint("Failed to send jam message:", error)
            }
        }
    }

    // MARK: - Receive Events

    private func handleRemoteMessage(_ message: JamMessage) {
        // Don't play back our own events
        guard message.senderId != String(deviceId) else { return }

        lastReceivedEvent = "\(message.senderName): \(eventDescription(message.event))"
        onRemoteEvent?(message.event)
    }

    private func eventDescription(_ event: JamEvent) -> String {
        switch event {
        case .noteOn(let midi, _, _): return "♪ \(midi)"
        case .noteOff: return "—"
        case .drumHit(let type): return "🥁 \(type)"
        case .bpmChange(let bpm): return "⏱ \(Int(bpm))"
        }
    }

    // MARK: - Leave Session

    func leaveSession() {
        session?.leave()
        session = nil
        messenger = nil
        isActive = false
        participants = []
        subscriptions.removeAll()
        for task in tasks { task.cancel() }
        tasks.removeAll()
    }
}
