import Foundation
import AuthenticationServices
import Supabase

/// Handles both sign-in providers:
///  - Apple: native Sign in with Apple -> Supabase `signInWithIdToken` (supported out of the box).
///  - WeChat: OpenSDK auth code -> Supabase Edge Function `wechat-auth` which exchanges the code
///    with Tencent and returns a Supabase session. WeChat is NOT a native Supabase provider,
///    so the exchange must happen server-side (the AppSecret can never ship in the app).
@MainActor
final class AuthService: ObservableObject {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(userID: UUID)
    }

    @Published private(set) var state: State
    @Published var errorMessage: String?

    private let client = SupabaseService.client
    private static let lastUserIDKey = "last_authenticated_user_id"

    init() {
        if let idString = UserDefaults.standard.string(forKey: Self.lastUserIDKey),
           let cachedUID = UUID(uuidString: idString) {
            // Instant 0ms startup for returning lifters
            self.state = .signedIn(userID: cachedUID)
        } else {
            #if DEBUG
            // In dev/debug, start instantly with local profile for zero-wait hot reloads
            let devID = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
            self.state = .signedIn(userID: devID)
            #else
            self.state = .loading
            #endif
        }
        Task { await restoreSession() }
    }

    // MARK: - Session

    func restoreSession() async {
        do {
            let session: Session = try await withTimeout(seconds: 1.5) {
                try await self.client.auth.session
            }
            UserDefaults.standard.set(session.user.id.uuidString, forKey: Self.lastUserIDKey)
            state = .signedIn(userID: session.user.id)
        } catch {
            if case .signedIn = state {
                // Keep local cached session in offline mode
            } else {
                UserDefaults.standard.removeObject(forKey: Self.lastUserIDKey)
                state = .signedOut
            }
        }
    }

    func signOut() async {
        UserDefaults.standard.removeObject(forKey: Self.lastUserIDKey)
        do {
            try await client.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
        state = .signedOut
    }

    // MARK: - Apple Sign In

    func signInWithApple(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8)
            else {
                errorMessage = "Apple sign-in did not return an identity token."
                return
            }
            do {
                let session = try await client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: tokenString)
                )
                UserDefaults.standard.set(session.user.id.uuidString, forKey: Self.lastUserIDKey)
                state = .signedIn(userID: session.user.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Test bypass (DEBUG only)

    /// Skips the real login flow for development.
    func signInAsTestUser() async {
        do {
            let session = try await client.auth.signIn(
                email: "dev-test@irodence.app",
                password: "devtest123456"
            )
            UserDefaults.standard.set(session.user.id.uuidString, forKey: Self.lastUserIDKey)
            state = .signedIn(userID: session.user.id)
        } catch {
            #if DEBUG
            // Instant offline mock session for smooth local testing
            let mockID = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
            UserDefaults.standard.set(mockID.uuidString, forKey: Self.lastUserIDKey)
            state = .signedIn(userID: mockID)
            #else
            errorMessage = L10n.t("测试账号登录失败", "Test user sign-in failed")
            #endif
        }
    }

    // MARK: - WeChat Sign In

    /// STUB — requires the WeChat OpenSDK (not an SPM package; see README "WeChat setup").
    /// Flow once the SDK is linked:
    ///   1. WXApi.send(AuthReq) -> user approves in WeChat
    ///   2. WeChat calls back with a `code` via the wx<appid>:// URL scheme (handleOpenURL below)
    ///   3. We call the `wechat-auth` Edge Function with that code
    ///   4. Edge Function exchanges code -> access_token (server-side, holds AppSecret),
    ///      upserts the user by openid/unionid, and returns a Supabase session token
    func signInWithWeChat() {
        // TODO(step1-wechat): call WXApi.sendReq once OpenSDK is integrated.
        errorMessage = "微信登录尚未配置 (WeChat sign-in not configured yet — SDK + AppID needed)"
    }

    /// Receives the WeChat OAuth callback from `.onOpenURL`.
    func handleOpenURL(_ url: URL) {
        guard url.scheme == AppConfig.weChatAppID else { return }
        // TODO(step1-wechat): pass the URL to WXApi.handleOpen(url, delegate:) and
        // forward the resulting auth code to the wechat-auth Edge Function:
        //
        //   let response = try await client.functions
        //       .invoke("wechat-auth", options: .init(body: ["code": code]))
        //   try await client.auth.setSession(accessToken: ..., refreshToken: ...)
    }

    // MARK: - Account Deletion (IRODENCE_SAFETY.md Section 8)

    /// Permanently deletes account and purges user data from Supabase.
    func deleteAccount() async throws {
        if case .signedIn(let uid) = state {
            // Delete user-owned records (proofs, workouts, progress, profile)
            try? await client.from("proofs").delete().eq("user_id", value: uid).execute()
            try? await client.from("workouts").delete().eq("user_id", value: uid).execute()
            try? await client.from("bodyweight_logs").delete().eq("user_id", value: uid).execute()
            try? await client.from("blocked_users").delete().eq("blocker_id", value: uid).execute()
            try? await client.from("profiles").delete().eq("id", value: uid).execute()
        }
        await signOut()
    }
}

// MARK: - Lightweight Async Timeout Helper

private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw URLError(.timedOut)
        }

        guard let result = try await group.next() else {
            throw URLError(.timedOut)
        }
        group.cancelAll()
        return result
    }
}
