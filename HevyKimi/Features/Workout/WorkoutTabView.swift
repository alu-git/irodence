import SwiftUI

/// Training tab root: start screen when idle, live logging UI when active.
struct WorkoutTabView: View {
    @EnvironmentObject private var manager: WorkoutManager
    @EnvironmentObject private var library: ExerciseService

    var body: some View {
        Group {
            if manager.isActive {
                ActiveWorkoutView()
            } else {
                WorkoutStartView()
            }
        }
        // Post-workout summary, shown after finish() resets the manager
        .sheet(item: summaryBinding) { wrapper in
            WorkoutSummaryView(summary: wrapper.summary)
        }
    }

    private var summaryBinding: Binding<IdentifiedSummary?> {
        Binding(
            get: { manager.summary.map(IdentifiedSummary.init) },
            set: { if $0 == nil { manager.clearSummary() } }
        )
    }

    /// Summary has no stable identity; wrap it for sheet(item:).
    struct IdentifiedSummary: Identifiable {
        let id = UUID()
        let summary: WorkoutManager.Summary
        init(_ summary: WorkoutManager.Summary) { self.summary = summary }
    }
}
