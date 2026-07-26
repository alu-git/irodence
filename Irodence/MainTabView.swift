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

            SocialView(userID: userID)
                .tabItem { Label("社交", systemImage: "person.2.fill") }
                .environmentObject(library)

            ProfileView(userID: userID)
                .tabItem { Label("我的", systemImage: "person.fill") }
                .environmentObject(library)
                .environmentObject(workoutManager)
        }
        // Warm the exercise library right after sign-in so every tab
        // (profile tiers, built-in templates, picker) has it ready.
        .task { await library.loadIfNeeded() }
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
        // Fill the parent so the content centers in the remaining space
        // instead of dragging sibling views (e.g. Social's segmented
        // picker) into the middle of the screen.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainTabView(userID: UUID())
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}
