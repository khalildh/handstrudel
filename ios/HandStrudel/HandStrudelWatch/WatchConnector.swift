import WatchConnectivity

class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func sendDrumHit(_ type: String) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["drumHit": type], replyHandler: nil)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
}
