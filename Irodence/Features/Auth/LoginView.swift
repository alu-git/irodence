import SwiftUI
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif

/// Login screen for 铁证 / Irodence.
/// WeChat is the primary CTA for the China market;
/// Sign in with Apple is required by Apple Review as a fallback.
/// Features:
/// - Exact brand slogans below existing logo.
/// - Official WeChat green button (#07C160).
/// - Standard Sign in with Apple button.
/// - Guest mode entry ("先逛逛，稍后登录").
/// - User agreement & privacy policy consent enforcement with shake and warning state.
/// - DEBUG-only developer controls below consent row.
struct LoginView: View {
    @EnvironmentObject private var authService: AuthService
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    @State private var isConsentChecked = false
    @State private var showConsentWarning = false
    @State private var consentShakeCount = 0
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false

    #if DEBUG
    @State private var showOnboardingPreview = false
    #endif

    var body: some View {
        VStack(spacing: 24) {
            // MARK: - Top Nav Bar / Language Switcher
            HStack {
                Spacer()
                Button {
                    let next = AppLanguage.isEnglish ? AppLanguage.zh : AppLanguage.en
                    language = next.rawValue
                    ForgeHaptics.selection()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 13, weight: .medium))
                        Text(AppLanguage.isEnglish ? "中文" : "English")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.surfaceRaised, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer()

            // MARK: - Logo & Slogan Block
            VStack(spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                VStack(spacing: 4) {
                    Text(L10n.t("力量，要有铁证", "Strength Demands Proof"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(L10n.t("记录 · 见证 · 锻造榜", "Log · Witness · Ranks"))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }

            Spacer()

            // MARK: - Auth Actions & Form
            VStack(spacing: 14) {
                // 1. WeChat Button — primary
                Button {
                    if !isConsentChecked {
                        triggerConsentWarning()
                    } else {
                        authService.signInWithWeChat()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text(L10n.t("微信登录", "Sign in with WeChat"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 7 / 255.0, green: 193 / 255.0, blue: 96 / 255.0))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                }
                .buttonStyle(.forgePress)

                // 2. Apple Button — fallback
                ZStack {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task { await authService.signInWithApple(result: result) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .opacity(0.001)

                    // Unified bilingual overlay
                    HStack(spacing: 8) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 19, weight: .semibold))
                        Text(L10n.t("通过 Apple 登录", "Sign in with Apple"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .allowsHitTesting(false)

                    if !isConsentChecked {
                        Color.black.opacity(0.001)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                triggerConsentWarning()
                            }
                    }
                }

                // 3. Guest Mode ("先逛逛，稍后登录")
                Button {
                    Task { await authService.signInAsTestUser() }
                } label: {
                    Text(L10n.t("先逛逛，稍后登录", "Browse as Guest"))
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                // 4. Consent Row
                HStack(alignment: .center, spacing: 6) {
                    Button {
                        isConsentChecked.toggle()
                        if isConsentChecked {
                            showConsentWarning = false
                        }
                    } label: {
                        Image(systemName: isConsentChecked ? "checkmark.square.fill" : "square")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(
                                isConsentChecked
                                    ? Theme.Colors.ember
                                    : (showConsentWarning ? Theme.Colors.rust : Theme.Colors.textMuted)
                            )
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 0) {
                        Text(L10n.t("我已阅读并同意", "I agree to the "))
                            .foregroundStyle(Theme.Colors.textMuted)
                        Button(L10n.t("《用户协议》", "Terms of Service")) {
                            showTermsOfService = true
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        Text(L10n.t("与", " and "))
                            .foregroundStyle(Theme.Colors.textMuted)
                        Button(L10n.t("《隐私政策》", "Privacy Policy")) {
                            showPrivacyPolicy = true
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .font(.system(size: 12, weight: .regular))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    showConsentWarning
                        ? Theme.Colors.rust.opacity(0.12)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                        .strokeBorder(
                            showConsentWarning ? Theme.Colors.rust.opacity(0.5) : Color.clear,
                            lineWidth: Theme.Border.hairline
                        )
                )
                .consentShake(trigger: consentShakeCount)
                .padding(.top, 4)

                // 5. Dev entries (DEBUG only)
                #if DEBUG
                VStack(spacing: 8) {
                    Button {
                        Task { await authService.signInAsTestUser() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Colors.ember)
                            Text(L10n.t("🧪 开发者测试快速登入", "🧪 Dev Mock Quick Login"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Colors.ember.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showOnboardingPreview = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.Colors.textMuted)
                            Text(L10n.t("预览新手引导与概念教程", "Preview Onboarding & Tutorial"))
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }
                    .buttonStyle(.plain)
                    .fullScreenCover(isPresented: $showOnboardingPreview) {
                        OnboardingPreviewContainer {
                            showOnboardingPreview = false
                        }
                    }
                }
                .padding(.top, 8)
                #endif

                if let error = authService.errorMessage {
                    Text(error)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.danger)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 32)
        }
        .background(Theme.Colors.surfaceBase.ignoresSafeArea())
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
    }

    private func triggerConsentWarning() {
        withAnimation(.easeInOut(duration: 0.15)) {
            showConsentWarning = true
            consentShakeCount += 1
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
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
