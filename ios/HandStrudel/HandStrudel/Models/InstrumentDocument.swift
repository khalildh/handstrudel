import Foundation
import UniformTypeIdentifiers

/// Any JSON value, kept exactly as received so an instrument file round-trips with the fields
/// this app version doesn't know (newer surfaces, the AI marker) intact.
indirect enum InstrumentJSON: Codable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([InstrumentJSON])
    case object([String: InstrumentJSON])

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let bool = try? value.decode(Bool.self) { self = .bool(bool) }
        else if let int = try? value.decode(Int.self) { self = .int(int) }
        else if let double = try? value.decode(Double.self) { self = .double(double) }
        else if let string = try? value.decode(String.self) { self = .string(string) }
        else if let array = try? value.decode([InstrumentJSON].self) { self = .array(array) }
        else { self = .object(try value.decode([String: InstrumentJSON].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .null: try value.encodeNil()
        case .bool(let bool): try value.encode(bool)
        case .int(let int): try value.encode(int)
        case .double(let double): try value.encode(double)
        case .string(let string): try value.encode(string)
        case .array(let array): try value.encode(array)
        case .object(let object): try value.encode(object)
        }
    }

    subscript(key: String) -> InstrumentJSON? {
        if case .object(let object) = self { return object[key] }
        return nil
    }
}

/// An instrument file as it travels between posts, the account and the Files app: the exact
/// document plus what `InstrumentSpec.load` made of it. It only exists if the loader accepted
/// the file, so every received instrument is validated before anything plays it (data only,
/// App Store Guideline 2.5.2). The document is otherwise opaque: format v2 surfaces and AI
/// markers pass through untouched.
struct InstrumentDocument: Codable, Equatable {
    /// The file as received (repairs live only in `spec`, so every loader repairs alike).
    let json: InstrumentJSON
    /// The playable instrument after the loader's checks and repairs.
    let spec: InstrumentSpec

    static let fileExtension = "handstrudel-instrument"
    static let fileType = UTType(exportedAs: "com.handstrudel.instrument", conformingTo: .json)

    enum LoadError: LocalizedError, Equatable {
        case rejected(InstrumentIssue?)

        var errorDescription: String? {
            switch self {
            case .rejected(.unsupportedVersion):
                return "This instrument was made with a newer HandStrudel. Update the app to play it."
            case .rejected(.tooLarge): return "This instrument file is too large."
            case .rejected: return "This isn't a HandStrudel instrument this app can play."
            }
        }
    }

    /// Validate a received file. Throws when the loader rejects it.
    init(data: Data) throws {
        let result = InstrumentSpec.load(data)
        guard let spec = result.spec, let json = try? JSONDecoder().decode(InstrumentJSON.self, from: data) else {
            throw LoadError.rejected(result.issues.first)
        }
        self.json = json
        self.spec = spec
    }

    init(json: InstrumentJSON) throws {
        try self.init(data: try JSONEncoder().encode(json))
    }

    /// An instrument known only as a decoded spec (bundled, or played by older code paths).
    init(spec: InstrumentSpec) {
        self.spec = spec
        json = (try? JSONEncoder().encode(spec)).flatMap { try? JSONDecoder().decode(InstrumentJSON.self, from: $0) } ?? .null
    }

    init(from decoder: Decoder) throws {
        try self.init(json: try InstrumentJSON(from: decoder))
    }

    func encode(to encoder: Encoder) throws { try json.encode(to: encoder) }

    /// Compact JSON with stable key order.
    var data: Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(json)) ?? Data()
    }

    var name: String { spec.name }

    /// Generated instruments carry `"ai_generated": true` or `"generator": {"kind": "ai"}`.
    var isAIGenerated: Bool {
        json["ai_generated"] == .bool(true) || json["generator"]?["kind"] == .string("ai")
    }

    // MARK: Remixing

    /// An editable copy with its own id and name. Unknown fields (newer data, the AI marker) are kept.
    func remixCopy(suffix: String = String(UUID().uuidString.prefix(6)).lowercased()) -> InstrumentDocument {
        let base = String(spec.id.prefix(InstrumentDocument.remixIDLimit))
        let name = String("\(spec.name) remix".prefix(InstrumentSpec.nameLimit))
        return (try? edited { $0["id"] = .string("\(base).remix-\(suffix)"); $0["name"] = .string(name) }) ?? self
    }

    /// Ids are at most 80 characters; leave room for ".remix-xxxxxx".
    private static let remixIDLimit = 80 - 13

    /// Apply changes to the top-level object and validate the result like any received file.
    func edited(_ change: (inout [String: InstrumentJSON]) -> Void) throws -> InstrumentDocument {
        guard case .object(var object) = json else { throw LoadError.rejected(.malformed) }
        change(&object)
        return try InstrumentDocument(json: .object(object))
    }

    /// Change one nested field, such as `surface.rest_radius`.
    func setting(_ path: [String], to value: InstrumentJSON) throws -> InstrumentDocument {
        func set(_ node: InstrumentJSON, _ path: ArraySlice<String>) -> InstrumentJSON {
            guard let key = path.first else { return value }
            guard case .object(var object) = node else { return node }
            object[key] = set(object[key] ?? .object([:]), path.dropFirst())
            return .object(object)
        }
        return try InstrumentDocument(json: set(json, path[...]))
    }

    // MARK: Files

    /// A `.handstrudel-instrument` file: the instrument JSON itself, readable by any HandStrudel app.
    func exportFile(in directory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let folder = directory.appendingPathComponent("instrument-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safeName = spec.name.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let url = folder.appendingPathComponent(safeName.isEmpty ? "Instrument" : safeName)
            .appendingPathExtension(Self.fileExtension)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(json).write(to: url, options: .atomic)
        return url
    }

    /// Read a file from Files, AirDrop or the share sheet, validating it like a post.
    static func importFile(at url: URL) throws -> InstrumentDocument {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        // Pretty-printed files can be a little larger than the 16 KB compact limit the loader enforces.
        guard size <= InstrumentSpec.byteLimit * 4 else { throw LoadError.rejected(.tooLarge) }
        let json = try JSONDecoder().decode(InstrumentJSON.self, from: Data(contentsOf: url))
        return try InstrumentDocument(json: json)
    }

    static func isInstrumentFile(_ url: URL) -> Bool {
        url.isFileURL && url.pathExtension.lowercased() == fileExtension
    }
}

/// The instrument a take was played on, saved with the draft and posted with it.
struct PostedInstrument: Codable, Equatable {
    var document: InstrumentDocument
    /// The post it came from, for credit. The server decides copy or remix by comparing files.
    var sourceVideoID: UUID?
}
