import UIKit
import CoreImage

final class WatermarkManager {
    /// Generate a QR code image for the App Store URL
    static func generateQR(for urlString: String = "https://handstrudel.com", size: CGFloat = 60) -> UIImage? {
        guard let data = urlString.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        let scale = size / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        return UIImage(ciImage: scaledImage)
    }

    /// Create a watermark overlay view that can be added during recording
    static func createWatermarkView(frame: CGRect) -> UIView {
        let container = UIView(frame: CGRect(x: frame.width - 140, y: frame.height - 80, width: 130, height: 70))
        container.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        container.layer.cornerRadius = 10

        // QR code
        if let qrImage = generateQR(size: 40) {
            let qrView = UIImageView(image: qrImage)
            qrView.frame = CGRect(x: 8, y: 15, width: 40, height: 40)
            qrView.tintColor = .white
            container.addSubview(qrView)
        }

        // Text
        let label = UILabel()
        label.text = "handstrudel"
        label.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .bold)
        label.textColor = UIColor.green
        label.frame = CGRect(x: 52, y: 18, width: 75, height: 14)
        container.addSubview(label)

        let sublabel = UILabel()
        sublabel.text = "scan to play"
        sublabel.font = UIFont.systemFont(ofSize: 8, weight: .medium)
        sublabel.textColor = UIColor.white.withAlphaComponent(0.6)
        sublabel.frame = CGRect(x: 52, y: 34, width: 75, height: 12)
        container.addSubview(sublabel)

        return container
    }
}
