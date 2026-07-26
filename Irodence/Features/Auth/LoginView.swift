import SwiftUI
import AuthenticationServices

/// Login screen. WeChat is the primary CTA for the China market;
/// Sign in with Apple is required by WeChat/Apple review as a fallback.
struct LoginView: View {
    @EnvironmentObject private var authService: AuthService
    #if DEBUG
    @State private var showOnboardingPreview = false
    #endif

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                Text("记录训练 · 冲击排行榜")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                // WeChat — primary
                Button {
                    authService.signInWithWeChat()
                } label: {
                    Label("微信登录", systemImage: "message.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.05, green: 0.78, blue: 0.52)) // WeChat green

                // Apple — fallback (required for App Store + WeChat review)
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task { await authService.signInWithApple(result: result) }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                #if DEBUG
                // Dev-only bypass: anonymous sign-in, or local preview if the
                // backend doesn't allow anonymous sessions yet.
                Button {
                    Task { await authService.signInAsTestUser() }
                } label: {
                    Label("测试进入", systemImage: "hammer.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)

                // Dev-only mock: walk through first-run onboarding without
                // creating a new account. Uses a throwaway ProfileService with
                // a random user ID — the profile UPDATE matches no row, so
                // 完成 "succeeds" silently and the cover dismisses.
                Button {
                    showOnboardingPreview = true
                } label: {
                    Label("预览新手引导", systemImage: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .fullScreenCover(isPresented: $showOnboardingPreview) {
                    OnboardingPreviewContainer {
                        showOnboardingPreview = false
                    }
                }
                #endif

                if let error = authService.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 48)
        }
    }
}

#if DEBUG
/// Owns the throwaway ProfileService as a StateObject so it survives parent
/// re-renders (constructing it inline in the cover closure would reset the
/// onboarding state on every authService publish).
private struct OnboardingPreviewContainer: View {
    @StateObject private var service = ProfileService(userID: UUID())
    let onFinished: () -> Void

    var body: some View {
        OnboardingView(service: service, onFinished: onFinished)
    }
}
#endif

#Preview {
    LoginView()
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}
