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
    @Published var participants: [String] = []
    @Published var lastReceivedEvent: String = ""

    private var session: GroupSession<HandStrudelActivity>?
    private var messenger: GroupSessionMessenger?
    private var subscriptions = Set<AnyCancellable>()
    private var sessionTask: Task<Void, Never>?

    let deviceId = UUID().uuidString.prefix(8).lowercased()
    var deviceName: String { UIDevice.current.name }

    var onRemoteEvent: ((JamEvent) -> Void)?

    init() {
        // Start listening for sessions immediately on init
        listenForSessions()
    }

    // MARK: - Listen for Sessions (runs from app launch)

    private func listenForSessions() {
        sessionTask = Task {
            for await session in HandStrudelActivity.sessions() {
                await configureSession(session)
            }
        }
    }

    // MARK: - Start Session (user presses button)

    func startSession() {
        let activity = HandStrudelActivity()
        Task {
            switch await activity.prepareForActivation() {
            case .activationPreferred:
                do {
                    _ = try await activity.activate()
                } catch {
                    debugPrint("Failed to activate activity:", error)
                }
            case .activationDisabled:
                debugPrint("SharePlay is disabled")
            case .cancelled:
                debugPrint("SharePlay activation cancelled")
            @unknown default:
                break
            }
        }
    }

    private func configureSession(_ session: GroupSession<HandStrudelActivity>) async {
        // Clean up old session
        self.session?.leave()
        self.subscriptions.removeAll()

        self.session = session
        let messenger = GroupSessionMessenger(session: session)
        self.messenger = messenger

        // Track participants
        session.$activeParticipants
            .receive(on: DispatchQueue.main)
            .sink { [weak self] participants in
                self?.participants = participants.map { $0.id.description }
                self?.isActive = participants.count > 0
            }
            .store(in: &subscriptions)

        session.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                if case .invalidated = state {
                    self?.isActive = false
                    self?.participants = []
                }
            }
            .store(in: &subscriptions)

        // Listen for messages
        Task {
            for await (message, _) in messenger.messages(of: JamMessage.self) {
                await MainActor.run {
                    handleRemoteMessage(message)
                }
            }
        }

        // Join the session
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
    }
}
