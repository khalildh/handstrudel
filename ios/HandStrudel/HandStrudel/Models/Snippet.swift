import Foundation

struct SavedSnippet: Identifiable, Codable {
    let id: UUID
    let code: String
    let timestamp: Date
    let bpm: Int

    init(code: String, bpm: Int) {
        self.id = UUID()
        self.code = code
        self.timestamp = Date()
        self.bpm = bpm
    }
}
