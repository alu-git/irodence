import SwiftUI

/// Dedicated past workouts history sheet showing all completed sessions.
/// Tapping any session opens WorkoutDetailView for full set/rep/weight details.
struct WorkoutHistorySheet: View {
    let userID: UUID
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service: FeedService

    init(userID: UUID) {
        self.userID = userID
        _service = StateObject(wrappedValue: FeedService(userID: userID))
    }

    private var myWorkouts: [FeedItem] {
        service.items
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.surfaceBase
                    .ignoresSafeArea()

                Group {
                    if service.isLoading && myWorkouts.isEmpty {
                        ForgeLoadingView(L10n.t("加载训练历史中…", "Loading workout history…"))
                    } else if myWorkouts.isEmpty {
                        ComingSoonView(
                            title: L10n.t("尚无完成的训练", "No Completed Workouts"),
                            systemImage: "clock.arrow.circlepath",
                            subtitle: L10n.t("完成一次训练后即可在此查看完整记录", "Log a workout to view full history here")
                        )
                    } else {
                        List {
                            ForEach(myWorkouts) { item in
                                NavigationLink(destination: WorkoutDetailView(item: item)) {
                                    workoutRow(item)
                                }
                                .listRowBackground(Theme.Colors.surfaceRaised)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    let workoutID = myWorkouts[index].id
                                    Task { await service.deleteWorkout(workoutID) }
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(L10n.t("历史训练记录", "Workout History"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("完成", "Done")) { dismiss() }
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .task {
                await service.load(filterUserID: userID)
            }
            .refreshable {
                await service.load(filterUserID: userID)
            }
        }
    }

    private func workoutRow(_ item: FeedItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.name)
                    .font(.headline.weight(.bold))
                Spacer()
                Text(formatDate(item.finishedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label(item.durationText, systemImage: "clock")
                Label(item.volumeText, systemImage: "dumbbell.fill")
                Label(L10n.t("\(item.setCount) 组", "\(item.setCount) Sets"), systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Exercise names summary
            if !item.exercises.isEmpty {
                Text(item.exercises.map(\.displayName).joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
