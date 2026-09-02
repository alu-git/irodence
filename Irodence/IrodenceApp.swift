import SwiftUI

@main
struct IrodenceApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @AppStorage(AppThemeMode.storageKey) private var themeMode = AppThemeMode.dark.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(networkMonitor)
                .preferredColorScheme(AppThemeMode(rawValue: themeMode)?.colorScheme)
                .onAppear {
                    OfflineSyncService.shared.syncPending()
                }
                // Handles WeChat OAuth callback URLs (wx<appid>://...)
                .onOpenURL { url in
                    authService.handleOpenURL(url)
                }
        }
    }
}
