import SwiftUI

/// Training tab root: start screen when idle, live logging UI when active.
struct WorkoutTabView: View {
    @EnvironmentObject private var manager: WorkoutManager
    @EnvironmentObject private var library: ExerciseService

    var body: some View {
        ZStack {
            if manager.isActive {
                ActiveWorkoutView()
            } else {
                WorkoutStartView()
            }
        }
        // Post-workout summary, shown after finish() sets manager.summary
        .fullScreenCover(item: $manager.summary) { summary in
            WorkoutSummaryView(
                summary: summary,
                workoutID: summary.workoutID ?? UUID(),
                userID: manager.userID
            )
        }
    }
}
