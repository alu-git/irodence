import SwiftUI

/// Placeholder tab shell — replaced feature-by-feature in steps 2–6.
struct MainTabView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        TabView {
            placeholder("训练", systemImage: "dumbbell.fill")
                .tabItem { Label("训练", systemImage: "dumbbell.fill") }

            placeholder("动作库", systemImage: "list.bullet.rectangle")
                .tabItem { Label("动作库", systemImage: "list.bullet.rectangle") }

            placeholder("排行榜", systemImage: "trophy.fill")
                .tabItem { Label("排行榜", systemImage: "trophy.fill") }

            profilePlaceholder
                .tabItem { Label("我的", systemImage: "person.fill") }
        }
    }

    private func placeholder(_ title: String, systemImage: String) -> some View {
        ComingSoonView(title: title, systemImage: systemImage, subtitle: "即将上线")
    }

    private var profilePlaceholder: some View {
        VStack(spacing: 16) {
            ComingSoonView(title: "我的", systemImage: "person.fill", subtitle: "等级与力量标准即将上线")
            Button("退出登录", role: .destructive) {
                Task { await authService.signOut() }
            }
        }
    }
}

/// iOS 16-compatible stand-in for ContentUnavailableView (iOS 17+).
struct ComingSoonView: View {
    let title: String
    let systemImage: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}
