import Foundation

/// Backend endpoints for accounts + the video feed.
///
/// The Supabase anon key is public by design (row-level security protects the
/// data); service-role and R2 secrets live only in the Edge Functions.
enum SocialConfig {
    /// Production values — fill in once the Supabase project exists.
    private static let productionURL = "https://eygrtqbtbhktptphqdnn.supabase.co"
    /// Supabase "publishable" key — safe to ship; RLS guards every table.
    private static let productionAnonKey = "sb_publishable_V6B0E_NNyf0ClZ13WpHegQ_W-wXH_im"
    /// Public base URL of the R2 media bucket: a Cloudflare-cached custom domain
    /// (no egress fees; Cloudflare's CSAM Scanning Tool checks cached images).
    private static let productionMediaBase = "https://media.handstrudel.com"

    /// DEBUG builds can point at a local stack: set SUPABASE_URL / SUPABASE_ANON_KEY /
    /// MEDIA_BASE_URL in the scheme's environment (`supabase start` prints them).
    private static func value(_ key: String, _ fallback: String) -> String {
        #if DEBUG
        if let v = ProcessInfo.processInfo.environment[key], !v.isEmpty { return v }
        #endif
        return fallback
    }

    static var supabaseURL: URL { URL(string: value("SUPABASE_URL", productionURL))! }
    static var supabaseAnonKey: String { value("SUPABASE_ANON_KEY", productionAnonKey) }
    static var mediaBaseURL: URL { URL(string: value("MEDIA_BASE_URL", productionMediaBase))! }

    /// False until real credentials are filled in, so the UI can hide social entry points.
    static var isConfigured: Bool { !supabaseAnonKey.hasPrefix("YOUR-") }

    /// Email-code sign-in. Production sends through Resend (custom SMTP on the
    /// Supabase project, from hello@handstrudel.com) using the 6-digit code
    /// templates mirrored in `supabase/templates/otp.html`. Set false to fall
    /// back to Sign in with Apple only if email delivery ever breaks.
    static let emailSignInEnabled = true

    static let termsURL = URL(string: "https://handstrudel.com/terms")!
    static let guidelinesURL = URL(string: "https://handstrudel.com/community")!

    static func mediaURL(_ key: String) -> URL { mediaBaseURL.appendingPathComponent(key) }
}
