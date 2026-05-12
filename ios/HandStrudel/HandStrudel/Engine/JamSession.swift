import Foundation
import GroupActivities
import Combine
import UIKit

// MARK: - Group Activity

struct HandStrudelActivity: GroupActivity {
    static var activityIdentifier = "com.handstrudel.app.jam"

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
    @Published var statusMessage: String = ""

    private var session: GroupSession<HandStrudelActivity>?
    private var messenger: GroupSessionMessenger?
    private var subscriptions = Set<AnyCancellable>()
    private var sessionTask: Task<Void, Never>?
    private var messageTask: Task<Void, Never>?

    let deviceId = UUID().uuidString.prefix(8).lowercased()
    var deviceName: String { UIDevice.current.name }

    var onRemoteEvent: ((JamEvent) -> Void)?

    init() {
        listenForSessions()
    }

    // MARK: - Listen for incoming sessions (runs from app launch)

    private func listenForSessions() {
        sessionTask = Task {
            for await session in HandStrudelActivity.sessions() {
                debugPrint("[Jam] Received session from GroupActivities")
                await configureSession(session)
            }
        }
    }

    // MARK: - Start/Join Session

    func startSession() {
        let activity = HandStrudelActivity()
        Task {
            debugPrint("[Jam] Preparing activity for activation...")
            switch await activity.prepareForActivation() {
            case .activationPreferred:
                do {
                    let result = try await activity.activate()
                    debugPrint("[Jam] Activity activated: \(result)")
                    statusMessage = "Waiting for others to join..."
                } catch {
                    debugPrint("[Jam] Activation failed: \(error)")
                    statusMessage = "Failed: \(error.localizedDescription)"
                }
            case .activationDisabled:
                debugPrint("[Jam] SharePlay is disabled by user")
                statusMessage = "SharePlay is disabled. Enable it in FaceTime settings."
            case .cancelled:
                debugPrint("[Jam] User cancelled SharePlay prompt")
                statusMessage = ""
            @unknown default:
                break
            }
        }
    }

    private func configureSession(_ session: GroupSession<HandStrudelActivity>) async {
        debugPrint("[Jam] Configuring session...")

        // Clean up old session
        messageTask?.cancel()
        self.session?.leave()
        self.subscriptions.removeAll()

        self.session = session
        let messenger = GroupSessionMessenger(session: session, deliveryMode: .unreliable)
        self.messenger = messenger

        // Track participants
        session.$activeParticipants
            .receive(on: DispatchQueue.main)
            .sink { [weak self] participants in
                guard let self else { return }
                self.participants = participants.map { $0.id.description }
                let count = participants.count
                self.isActive = count > 0
                debugPrint("[Jam] Participants: \(count)")
                if count > 1 {
                    self.statusMessage = "\(count) people jamming"
                } else if count == 1 {
                    self.statusMessage = "Connected — waiting for others"
                }
            }
            .store(in: &subscriptions)

        session.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                debugPrint("[Jam] Session state: \(state)")
                if case .invalidated = state {
                    self?.isActive = false
                    self?.participants = []
                    self?.statusMessage = "Session ended"
                }
            }
            .store(in: &subscriptions)

        // Listen for messages
        messageTask = Task {
            for await (message, _) in messenger.messages(of: JamMessage.self) {
                await MainActor.run {
                    handleRemoteMessage(message)
                }
            }
        }

        // Join the session
        session.join()
        isActive = true
        debugPrint("[Jam] Joined session")
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
                debugPrint("[Jam] Send failed: \(error)")
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
        case .noteOn(let midi, _, _): return "note \(midi)"
        case .noteOff: return "—"
        case .drumHit(let type): return "drum \(type)"
        case .bpmChange(let bpm): return "bpm \(Int(bpm))"
        }
    }

    // MARK: - Leave Session

    func leaveSession() {
        messageTask?.cancel()
        session?.leave()
        session = nil
        messenger = nil
        isActive = false
        participants = []
        statusMessage = ""
        subscriptions.removeAll()
        debugPrint("[Jam] Left session")
    }
}
