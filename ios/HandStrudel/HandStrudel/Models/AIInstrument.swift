import Foundation
import Supabase

/// "Make an instrument": a prompt goes to the `generate-instrument` Edge
/// Function (Claude, by Anthropic), which returns an instrument *file*. The
/// file goes through `InstrumentSpec.load` like any bundled one and is drawn by
/// the app's own code; nothing returned is executed (Guideline 2.5.2).
///
/// Generated instruments are structure only. Music the prompt implied ("in D
/// minor", "slow") comes back separately as a `MusicSuggestion` the player can
/// apply with one tap; it is never part of the instrument.
struct GeneratedInstrument: Equatable {
    /// The instrument, after the app's loader.
    let spec: InstrumentSpec
    /// The instrument file exactly as the server sent it (keeps fields this
    /// version of the app doesn't know, for saving and sharing).
    let body: Data
    /// ok, repaired, or fallback (the closest built-in when generation failed).
    let status: String
    let suggestion: MusicSuggestion?
    let quotaRemaining: Int?

    var isFallback: Bool { status == "fallback" }
}

/// Music the prompt implied, offered separately from the instrument.
struct MusicSuggestion: Codable, Equatable {
    var key: String?
    var scale: String?
    var bpm: Int?

    var musicKey: MusicKey? { key.flatMap(MusicKey.init(rawValue:)) }
    var builtInScale: BuiltInScale? { scale.flatMap(BuiltInScale.init(rawValue:)) }

    /// "D Minor · 70 BPM"
    var summary: String {
        var parts: [String] = []
        let tonality = [musicKey?.rawValue, builtInScale?.rawValue].compactMap { $0 }.joined(separator: " ")
        if !tonality.isEmpty { parts.append(tonality) }
        if let bpm { parts.append("\(bpm) BPM") }
        return parts.joined(separator: " · ")
    }

    var isEmpty: Bool { musicKey == nil && builtInScale == nil && bpm == nil }
}

enum AIInstrumentError: LocalizedError, Equatable {
    case signInRequired
    case quotaExceeded(String)
    case promptBlocked(String)
    case invalidPrompt(String)
    case unreachable
    case server(String)

    var errorDescription: String? {
        switch self {
        case .signInRequired: return "Sign in to make instruments."
        case .quotaExceeded(let message), .promptBlocked(let message), .invalidPrompt(let message), .server(let message):
            return message
        case .unreachable: return "Couldn't reach HandStrudel. Check your connection and try again."
        }
    }
}

/// What the generator needs: the prompt, plus for a refine the current
/// instrument file and the prompt that made it.
struct AIInstrumentRequest: Equatable {
    var prompt: String
    var current: Data?
    var originalPrompt: String?
}

protocol AIInstrumentGenerating {
    func generate(_ request: AIInstrumentRequest) async throws -> GeneratedInstrument
}

/// Signed-in requests to Supabase (Edge Function + `my_instruments` table).
struct SupabaseEndpoint {
    var baseURL: URL
    var anonKey: String
    /// The signed-in user's access token, or nil when signed out.
    var accessToken: () async -> String?

    /// The app's Supabase project and session. DEBUG builds can point at a
    /// loopback mock with `HANDSTRUDEL_AI_INSTRUMENT_BASE_URL` and a fixed
    /// `HANDSTRUDEL_AI_INSTRUMENT_TOKEN` (UI tests).
    static var live: SupabaseEndpoint {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let base = env["HANDSTRUDEL_AI_INSTRUMENT_BASE_URL"].flatMap(URL.init(string:)), base.host == "127.0.0.1" {
            let token = env["HANDSTRUDEL_AI_INSTRUMENT_TOKEN"]
            return SupabaseEndpoint(baseURL: base, anonKey: "ai-instrument-fixture", accessToken: { token })
        }
        #endif
        return SupabaseEndpoint(baseURL: SocialConfig.supabaseURL, anonKey: SocialConfig.supabaseAnonKey,
                                accessToken: { try? await supabase.auth.session.accessToken })
    }

    func request(_ path: String, method: String, body: Data? = nil, query: [URLQueryItem] = []) async throws -> URLRequest {
        guard let token = await accessToken() else { throw AIInstrumentError.signInRequired }
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 30
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}

/// Calls `generate-instrument`.
struct AIInstrumentClient: AIInstrumentGenerating {
    var endpoint: SupabaseEndpoint = .live
    var send: (URLRequest) async throws -> (Data, URLResponse) = { try await URLSession.shared.data(for: $0) }

    func generate(_ request: AIInstrumentRequest) async throws -> GeneratedInstrument {
        var body: [String: Any] = ["prompt": request.prompt]
        if let current = request.current, let object = try? JSONSerialization.jsonObject(with: current) {
            body["current"] = object
        }
        if let original = request.originalPrompt { body["original_prompt"] = original }
        let urlRequest = try await endpoint.request("functions/v1/generate-instrument", method: "POST",
                                                    body: try JSONSerialization.data(withJSONObject: body))
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await send(urlRequest)
        } catch {
            throw AIInstrumentError.unreachable
        }
        return try Self.decode(data, status: (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    /// Turn a response into an instrument, through the same loader as bundled files.
    static func decode(_ data: Data, status: Int) throws -> GeneratedInstrument {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let message = object?["error"] as? String ?? "Something went wrong. Try again."
        switch status {
        case 200: break
        case 401: throw AIInstrumentError.signInRequired
        case 429: throw AIInstrumentError.quotaExceeded(message)
        case 422: throw AIInstrumentError.promptBlocked(message)
        case 400: throw AIInstrumentError.invalidPrompt(message)
        default: throw AIInstrumentError.server(message)
        }
        guard let object, let instrument = object["instrument"] as? [String: Any],
              let file = try? JSONSerialization.data(withJSONObject: instrument, options: [.sortedKeys]) else {
            throw AIInstrumentError.server("The instrument didn't arrive. Try again.")
        }
        guard let spec = InstrumentSpec.load(file).spec else {
            throw AIInstrumentError.server("That instrument needs a newer version of HandStrudel.")
        }
        var suggestion: MusicSuggestion?
        if let raw = object["suggested_music"] as? [String: Any],
           let encoded = try? JSONSerialization.data(withJSONObject: raw) {
            suggestion = (try? JSONDecoder().decode(MusicSuggestion.self, from: encoded)).flatMap { $0.isEmpty ? nil : $0 }
        }
        let quota = (object["quota"] as? [String: Any])?["remaining"] as? Int
        return GeneratedInstrument(spec: spec, body: file, status: object["status"] as? String ?? "ok",
                                   suggestion: suggestion, quotaRemaining: quota)
    }
}

/// One-time consent before the first prompt leaves the device (Guideline 5.1.2(i)).
enum AIInstrumentConsent {
    static let defaultsKey = "aiInstrumentConsent.v1"
    static var hasConsented: Bool {
        get { UserDefaults.standard.bool(forKey: defaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }
}

/// Example prompts shown as chips.
enum AIInstrumentExamples {
    static let prompts = [
        "Huge zones I can hit without looking",
        "Chords on the right, glowing notes",
        "A calm wheel for slow, sad songs",
        "Arpeggio harp from the chord I hold",
    ]
    static let refinements = ["Bigger zones", "More glow", "Smaller rest hole", "Chords on the other side"]
}
