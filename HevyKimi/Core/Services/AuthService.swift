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

    @Published private(set) var state: State = .loading
    @Published var errorMessage: String?

    private let client = SupabaseService.client

    init() {
        Task { await restoreSession() }
    }

    // MARK: - Session

    func restoreSession() async {
        do {
            let session = try await client.auth.session
            state = .signedIn(userID: session.user.id)
        } catch {
            state = .signedOut
        }
    }

    func signOut() async {
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
                state = .signedIn(userID: session.user.id)
            } catch {
                errorMessage = error.localizedDescription
            }
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
        _ = url
    }
}
