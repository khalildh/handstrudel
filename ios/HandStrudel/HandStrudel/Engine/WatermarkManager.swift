import UIKit
import CoreImage

final class WatermarkManager {
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

    /// Create a watermark overlay — positioned in the safe zone that Instagram won't crop
    static func createWatermarkView(frame: CGRect) -> UIView {
        // Position: right side, 30% from top — safe from Instagram's top/bottom crop
        let w: CGFloat = 140
        let h: CGFloat = 50
        let container = UIView(frame: CGRect(
            x: frame.width - w - 16,
            y: frame.height * 0.30,
            width: w,
            height: h
        ))
        container.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        container.layer.cornerRadius = 12

        // QR code
        if let qrImage = generateQR(size: 34) {
            let qrView = UIImageView(image: qrImage)
            qrView.frame = CGRect(x: 8, y: 8, width: 34, height: 34)
            qrView.backgroundColor = .white
            qrView.layer.cornerRadius = 4
            container.addSubview(qrView)
        }

        // Text stack
        let label = UILabel()
        label.text = "handstrudel"
        label.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        label.textColor = UIColor(red: 0, green: 1, blue: 0.62, alpha: 1)
        label.frame = CGRect(x: 48, y: 10, width: 88, height: 16)
        container.addSubview(label)

        let sublabel = UILabel()
        sublabel.text = "scan to play 🎵"
        sublabel.font = UIFont.systemFont(ofSize: 9, weight: .medium)
        sublabel.textColor = UIColor.white.withAlphaComponent(0.7)
        sublabel.frame = CGRect(x: 48, y: 27, width: 88, height: 14)
        container.addSubview(sublabel)

        return container
    }
}
