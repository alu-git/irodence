import SwiftUI

/// Main tab shell. Owns the shared services (exercise library, active
/// workout) and injects them into the tabs.
struct MainTabView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var library = ExerciseService()
    @StateObject private var workoutManager: WorkoutManager
    private let userID: UUID

    init(userID: UUID) {
        self.userID = userID
        _workoutManager = StateObject(wrappedValue: WorkoutManager(userID: userID))
    }

    var body: some View {
        TabView {
            WorkoutTabView()
                .tabItem { Label("训练", systemImage: "dumbbell.fill") }
                .environmentObject(workoutManager)
                .environmentObject(library)

            ExerciseLibraryView()
                .tabItem { Label("动作库", systemImage: "list.bullet.rectangle") }
                .environmentObject(library)

            placeholder("排行榜", systemImage: "trophy.fill")
                .tabItem { Label("排行榜", systemImage: "trophy.fill") }

            ProfileView(userID: userID)
                .tabItem { Label("我的", systemImage: "person.fill") }
                .environmentObject(library)
        }
    }

    private func placeholder(_ title: String, systemImage: String) -> some View {
        ComingSoonView(title: title, systemImage: systemImage, subtitle: "即将上线")
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
    MainTabView(userID: UUID())
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}
