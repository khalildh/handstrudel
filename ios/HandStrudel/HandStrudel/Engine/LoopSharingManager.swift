import UIKit

// NOTE: To fully support .handstrudel file import via AirDrop, register the UTType in Info.plist:
//   - Add a UTImportedTypeDeclarations entry for "com.handstrudel.loop" conforming to "public.json"
//     with extension "handstrudel"
//   - Add a CFBundleDocumentTypes entry for the same UTType so the app appears in the share sheet
//     and can open .handstrudel files directly

final class LoopSharingManager {
    /// Export a loop as a .handstrudel file (JSON) and present share sheet
    static func shareLoop(_ loop: RecordedLoop, from viewController: UIViewController? = nil) {
        guard let data = try? JSONEncoder().encode(loop) else { return }

        let fileName = "\(loop.name.replacingOccurrences(of: " ", with: "_")).handstrudel"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)

        if let vc = viewController ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController {
            vc.present(activityVC, animated: true)
        }
    }

    /// Import a .handstrudel file
    static func importLoop(from url: URL) -> RecordedLoop? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RecordedLoop.self, from: data)
    }

    /// Export multiple loops as a composition file
    static func shareComposition(_ composition: Composition, loops: [RecordedLoop], from viewController: UIViewController? = nil) {
        struct ExportBundle: Codable {
            let composition: Composition
            let loops: [RecordedLoop]
        }
        let bundle = ExportBundle(composition: composition, loops: loops)
        guard let data = try? JSONEncoder().encode(bundle) else { return }

        let fileName = "\(composition.name.replacingOccurrences(of: " ", with: "_")).handstrudel"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)

        if let vc = viewController ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController {
            vc.present(activityVC, animated: true)
        }
    }
}
