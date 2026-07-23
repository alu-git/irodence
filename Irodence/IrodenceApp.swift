import SwiftUI

@main
struct IrodenceApp: App {
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .preferredColorScheme(.dark)
                // Handles WeChat OAuth callback URLs (wx<appid>://...)
                .onOpenURL { url in
                    authService.handleOpenURL(url)
                }
        }
    }
}
