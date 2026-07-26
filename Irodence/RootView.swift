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
                VStack(spacing: 24) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                    ProgressView()
                }
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
        // Bilingual model strings (exercise names, muscle groups, tiers…)
        // read UserDefaults statically via L10n.t, so views rendering them
        // hold no locale dependency and would otherwise keep showing the
        // previous language after a switch. Rebuild the tree on change.
        .id(language)
    }
}

#Preview {
    RootView()
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}
