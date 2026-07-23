import SwiftUI

/// Switches between auth flow and the main app based on session state.
struct RootView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        Group {
            switch authService.state {
            case .loading:
                ProgressView()
            case .signedOut:
                LoginView()
            case .signedIn(let userID):
                MainTabView(userID: userID)
            }
        }
        .animation(.default, value: authService.state)
    }
}

#Preview {
    RootView()
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}
