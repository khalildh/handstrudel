import UIKit
import MessageUI

final class iMessageManager: NSObject, MFMessageComposeViewControllerDelegate {
    static let shared = iMessageManager()

    /// Share a recorded loop as an attachment in iMessage
    func shareLoop(_ loop: RecordedLoop, from viewController: UIViewController? = nil) {
        guard MFMessageComposeViewController.canSendText(),
              MFMessageComposeViewController.canSendAttachments() else { return }

        guard let data = try? JSONEncoder().encode(loop) else { return }

        let fileName = "\(loop.name.replacingOccurrences(of: " ", with: "_")).handstrudel"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)

        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = self
        controller.body = "Check out my HandStrudel loop! 🎵🤚"
        controller.addAttachmentURL(tempURL, withAlternateFilename: fileName)

        if let vc = viewController ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController {
            vc.present(controller, animated: true)
        }
    }

    /// Share a text invite to download HandStrudel
    func shareInvite(from viewController: UIViewController? = nil) {
        guard MFMessageComposeViewController.canSendText() else { return }

        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = self
        controller.body = "Make music with your hands! 🤚🎵 Try HandStrudel: https://handstrudel.com"

        if let vc = viewController ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController {
            vc.present(controller, animated: true)
        }
    }

    // MARK: - MFMessageComposeViewControllerDelegate

    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
    }
}
