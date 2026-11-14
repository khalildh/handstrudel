import AuthenticationServices
import SwiftUI

/// Sign in (Apple or emailed code), then pick a username and accept the terms.
/// Dismisses itself once the account is ready to post.
struct SignInView: View {
    @ObservedObject var auth: AuthManager
    var reason = "Sign in to post your performances."
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Group {
                if auth.isSignedIn {
                    ProfileSetupView(auth: auth)
                } else {
                    signInForm
                }
            }
            .scrollContentBackground(.hidden)
            .background(StudioStyle.background)
            .navigationTitle(auth.isSignedIn ? "Your profile" : "Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { auth.errorMessage != nil }, set: { if !$0 { auth.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(auth.errorMessage ?? "") }
        }
        .tint(StudioStyle.accent)
        .onChange(of: auth.needsProfileSetup) { needs in
            if !needs && auth.isSignedIn { dismiss() }
        }
    }

    private var signInForm: some View {
        Form {
            Section {
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(StudioStyle.muted)
                    .listRowBackground(StudioStyle.surface)
                SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 48)
                    .overlay {
                        // Our own ASAuthorizationController flow (needs the nonce);
                        // the system button is just the approved artwork.
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { Task { await auth.signInWithApple() } }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(StudioStyle.surface)
            }
            if SocialConfig.emailSignInEnabled { emailSection }
        }
    }

    private var emailSection: some View {
        Group {
            Section("Or use your email") {
                TextField("you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .listRowBackground(StudioStyle.surface)
                if codeSent {
                    TextField("6-digit code", text: $code)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                        .listRowBackground(StudioStyle.surface)
                    Button("Sign in") {
                        Task { busy = true; await auth.verifyEmailCode(code, email: email); busy = false }
                    }
                    .disabled(code.count < 6 || busy)
                    .listRowBackground(StudioStyle.surface)
                } else {
                    Button("Email me a code") {
                        Task { busy = true; codeSent = await auth.sendEmailCode(to: email); busy = false }
                    }
                    .disabled(!email.contains("@") || busy)
                    .listRowBackground(StudioStyle.surface)
                }
            }
        }
    }
}

/// Username + terms acceptance (required before posting; App Store 1.2).
struct ProfileSetupView: View {
    @ObservedObject var auth: AuthManager
    @State private var username = ""
    @State private var agreed = false
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                TextField("username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: username) { username = Profile.normalizeUsername($0) }
            } header: {
                Text("Choose a username")
            } footer: {
                Text("3–20 characters: lowercase letters, numbers and _")
            }
            Section {
                Toggle(isOn: $agreed) {
                    Text("I agree to the [Terms](\(SocialConfig.termsURL.absoluteString)) and [Community Guidelines](\(SocialConfig.guidelinesURL.absoluteString)). No objectionable content or abusive behavior.")
                        .font(.footnote)
                }
            }
            Section {
                Button("Continue") {
                    Task { busy = true; _ = await auth.completeProfile(username: username); busy = false }
                }
                .disabled(!Profile.isValidUsername(username) || !agreed || busy)
            }
        }
        .onAppear { username = auth.profile?.username ?? "" }
    }
}
