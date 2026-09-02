import SwiftUI

/// Switches between auth flow and the main app based on session state.
struct RootView: View {
    @EnvironmentObject private var authService: AuthService
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue
    @AppStorage(TextSizePreference.storageKey) private var textSize = TextSizePreference.standard.rawValue

    var body: some View {
        Group {
            switch authService.state {
            case .loading:
                ForgeLoadingScreen(message: L10n.t("初始化熔炉…", "Initializing Forge…"))
            case .signedOut:
                LoginView()
            case .signedIn(let userID):
                // Routes brand-new accounts through first-run onboarding
                OnboardingGateView(userID: userID)
            }
        }
        .animation(.default, value: authService.state)
        // In-app language + text-size overrides (see Profile → 设置)
        .environment(\.locale, (AppLanguage(rawValue: language) ?? .zh).locale)
        .dynamicTypeSize((TextSizePreference(rawValue: textSize) ?? .standard).dynamicTypeSize)
    }
}

#Preview {
    RootView()
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}
