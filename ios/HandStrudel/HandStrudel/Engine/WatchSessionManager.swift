import WatchConnectivity

// iPhone-side WatchConnectivity manager.
// Receives drum hit messages from the companion Apple Watch app.
//
// To wire up: instantiate in your iOS app's root and set `onDrumHit`
// to forward hits to the audio engine (e.g. DrumModeManager).

final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isWatchConnected = false
    var onDrumHit: ((String) -> Void)?

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.isWatchConnected = session.isReachable }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isWatchConnected = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let hitType = message["drumHit"] as? String {
            DispatchQueue.main.async { self.onDrumHit?(hitType) }
        }
    }
}
