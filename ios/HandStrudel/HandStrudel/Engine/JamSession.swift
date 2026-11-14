import Foundation
import GroupActivities
import Combine

struct HandStrudelActivity: GroupActivity {
    static let activityIdentifier = "com.handstrudel.app.jam"

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "HandStrudel Jam"
        metadata.subtitle = "Make music together"
        metadata.type = .generic
        return metadata
    }
}

enum JamEvent: Codable, Equatable, Sendable {
    case notes(pitches: [Int], program: UInt8?, waveform: String, velocity: Double, duration: Double)
    case drumHit(hitType: String)

    // Validate peer data before routing any strings into the WebView's audio bridge.
    var isPlayable: Bool {
        switch self {
        case let .notes(pitches, program, waveform, velocity, duration):
            return (1...4).contains(pitches.count)
                && pitches.allSatisfy { (0...127).contains($0) }
                && (program.map { $0 <= 127 } ?? true)
                && WAVEFORMS.contains { $0.id == waveform }
                && (0...1).contains(velocity)
                && (0.05...1).contains(duration)
        case .drumHit(let hitType):
            return DrumModeManager.allDrums.contains { $0.hitType == hitType }
        }
    }
}

struct JamHeldVoice: Codable, Equatable, Sendable {
    var attack = UUID()
    var pitches: [Int]
    let program: UInt8?
    let waveform: String
    let velocity: Double
}

struct JamHeldState: Codable, Sendable {
    let sequence: UInt64
    let voices: [String: JamHeldVoice]

    var isValid: Bool {
        voices.count <= 24 && voices.allSatisfy { id, voice in
            (1...40).contains(id.utf8.count)
                && id.utf8.allSatisfy { $0 == 45 || (48...57).contains($0) || (97...122).contains($0) }
                && JamEvent.notes(pitches: voice.pitches, program: voice.program,
                                  waveform: voice.waveform, velocity: voice.velocity, duration: 0.25).isPlayable
        }
    }
}

struct JamPeerState {
    static let timeout: TimeInterval = 2.5
    private(set) var voices: [String: JamHeldVoice] = [:]
    private var sequence: UInt64?
    private var lastUpdate: TimeInterval = 0

    // A late snapshot must never restore an already released note.
    mutating func accept(_ state: JamHeldState, now: TimeInterval) -> Bool {
        guard state.isValid, sequence.map({ state.sequence > $0 }) ?? true else { return false }
        sequence = state.sequence
        lastUpdate = now
        let changed = voices != state.voices
        voices = state.voices
        return changed
    }

    mutating func expire(now: TimeInterval) -> Bool {
        guard !voices.isEmpty, now - lastUpdate >= Self.timeout else { return false }
        voices.removeAll()
        return true
    }
}

@MainActor
final class JamSessionManager: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var participantCount = 0
    @Published private(set) var isConnecting = false
    @Published var errorMessage: String?

    private let groupState = GroupStateObserver()
    private var session: GroupSession<HandStrudelActivity>?
    private var messenger: GroupSessionMessenger?
    private var heldMessenger: GroupSessionMessenger?
    private var subscriptions = Set<AnyCancellable>()
    private var messageTask: Task<Void, Never>?
    private var heldTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var activationTask: Task<Void, Never>?
    private var heldVoices: [String: JamHeldVoice] = [:]
    private var peers: [UUID: JamPeerState] = [:]
    private var activePeers: Set<UUID> = []
    private var heldSequence: UInt64 = 0

    var canActivate: Bool { groupState.isEligibleForGroupSession }
    var onRemoteEvent: ((JamEvent) -> Void)?
    var onRemoteVoices: ((UUID, [String: JamHeldVoice]) -> Void)?
    var onSessionCleared: (() -> Void)?

    func listenForSessions() async {
        for await session in HandStrudelActivity.sessions() {
            configure(session)
        }
    }

    func startSession() {
        guard !isActive, !isConnecting else { return }
        isConnecting = true
        activationTask = Task { [weak self] in
            defer { self?.isConnecting = false }
            do {
                let activated = try await HandStrudelActivity().activate()
                if !activated, !Task.isCancelled {
                    self?.errorMessage = "SharePlay didn’t start. Try again from your FaceTime call."
                }
            } catch {
                if !Task.isCancelled {
                    self?.errorMessage = "Couldn’t start SharePlay. Check that SharePlay is enabled in FaceTime settings."
                }
            }
        }
    }

    private func configure(_ newSession: GroupSession<HandStrudelActivity>) {
        guard session?.id != newSession.id else { return }
        clearSession(leave: true)
        session = newSession
        let messenger = GroupSessionMessenger(session: newSession, deliveryMode: .unreliable)
        self.messenger = messenger
        let heldMessenger = GroupSessionMessenger(session: newSession, deliveryMode: .reliable)
        self.heldMessenger = heldMessenger
        let sessionID = newSession.id
        let localParticipant = newSession.localParticipant

        newSession.$activeParticipants
            .receive(on: DispatchQueue.main)
            .sink { [weak self] participants in
                guard let self, self.session?.id == sessionID else { return }
                let active = Set(participants.subtracting([localParticipant]).map(\.id))
                for id in self.activePeers.subtracting(active) {
                    self.peers[id] = nil
                    self.onRemoteVoices?(id, [:])
                }
                let hasNewPeer = !active.subtracting(self.activePeers).isEmpty
                self.activePeers = active
                self.participantCount = active.count + 1
                if hasNewPeer, !self.heldVoices.isEmpty { self.sendHeldState() }
            }
            .store(in: &subscriptions)

        newSession.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self, self.session?.id == sessionID else { return }
                switch state {
                case .waiting: break
                case .joined:
                    self.isActive = true
                    if !self.heldVoices.isEmpty { self.sendHeldState() }
                case .invalidated: self.clearSession(leave: false)
                @unknown default: break
                }
            }
            .store(in: &subscriptions)

        messageTask = Task { [weak self] in
            for await (event, context) in messenger.messages(of: JamEvent.self) {
                guard let self, self.session?.id == sessionID else { return }
                if context.source != localParticipant, event.isPlayable {
                    self.onRemoteEvent?(event)
                }
            }
        }
        heldTask = Task { [weak self] in
            for await (state, context) in heldMessenger.messages(of: JamHeldState.self) {
                guard let self, self.session?.id == sessionID else { return }
                let peer = context.source.id
                guard peer != localParticipant.id, self.activePeers.contains(peer) else { continue }
                if self.peers[peer, default: JamPeerState()].accept(state, now: ProcessInfo.processInfo.systemUptime) {
                    self.onRemoteVoices?(peer, state.voices)
                }
            }
        }
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, !Task.isCancelled, self.session?.id == sessionID else { return }
                if !self.heldVoices.isEmpty { self.sendHeldState() }
                let now = ProcessInfo.processInfo.systemUptime
                for peer in Array(self.peers.keys) where self.peers[peer]?.expire(now: now) == true {
                    self.onRemoteVoices?(peer, [:])
                }
            }
        }
        newSession.join()
    }

    func setHeldVoice(_ id: String, voice: JamHeldVoice?) {
        guard heldVoices[id] != voice else { return }
        guard voice == nil || heldVoices[id] != nil || heldVoices.count < 24 else { return }
        heldVoices[id] = voice
        sendHeldState()
    }

    func clearHeldVoices() {
        guard !heldVoices.isEmpty else { return }
        heldVoices.removeAll()
        sendHeldState()
    }

    func slideHeldVoice(_ id: String, pitches: [Int]) {
        guard var voice = heldVoices[id] else { return }
        voice.pitches = pitches
        setHeldVoice(id, voice: voice)
    }

    func replayRemoteVoices() {
        let now = ProcessInfo.processInfo.systemUptime
        for id in Array(peers.keys) {
            _ = peers[id]?.expire(now: now)
            if let state = peers[id] { onRemoteVoices?(id, state.voices) }
        }
    }

    private func sendHeldState() {
        guard let heldMessenger, isActive, !activePeers.isEmpty else { return }
        heldSequence &+= 1
        let state = JamHeldState(sequence: heldSequence, voices: heldVoices)
        Task {
            do {
                try await heldMessenger.send(state)
            } catch {
                debugPrint("[Jam] Held state send failed: \(error)")
            }
        }
    }

    func sendEvent(_ event: JamEvent) {
        guard let messenger, isActive, participantCount > 1, event.isPlayable else { return }
        Task {
            do {
                try await messenger.send(event)
            } catch {
                debugPrint("[Jam] Send failed: \(error)")
            }
        }
    }

    func leaveSession() {
        activationTask?.cancel()
        activationTask = nil
        isConnecting = false
        clearSession(leave: true)
    }

    private func clearSession(leave: Bool) {
        let previous = session
        session = nil
        messageTask?.cancel()
        messageTask = nil
        heldTask?.cancel()
        heldTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        peers.removeAll()
        activePeers.removeAll()
        heldSequence = 0
        subscriptions.removeAll()
        if leave { previous?.leave() }
        messenger = nil
        heldMessenger = nil
        isActive = false
        participantCount = 0
        if previous != nil { onSessionCleared?() }
    }
}
