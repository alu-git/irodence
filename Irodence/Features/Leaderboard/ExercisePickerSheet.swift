import SwiftUI

/// Searchable sheet to pick an exercise from the 动作库 with recent picks pinned.
struct ExercisePickerSheet: View {
    @ObservedObject var library: ExerciseService
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @AppStorage("recentLeaderboardExerciseIDs") private var recentExerciseIDsRaw: String = ""

    private var recentExerciseIDs: [UUID] {
        recentExerciseIDsRaw
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
    }

    private var recentExercises: [Exercise] {
        let all = library.exercises
        return recentExerciseIDs.compactMap { id in
            all.first(where: { $0.id == id })
        }
    }

    private var filteredExercises: [Exercise] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return library.exercises
        }
        let query = searchText.lowercased()
        return library.exercises.filter {
            $0.nameZh.lowercased().contains(query) ||
            $0.nameEn.lowercased().contains(query)
        }
    }

    private var groupedExercises: [(MuscleGroup, [Exercise])] {
        var groups: [MuscleGroup: [Exercise]] = [:]
        for ex in filteredExercises {
            groups[ex.primaryMuscle, default: []].append(ex)
        }
        return MuscleGroup.allCases.compactMap { group in
            if let list = groups[group], !list.isEmpty {
                return (group, list)
            }
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.surfaceBase
                    .ignoresSafeArea()

                List {
                    // 1. Recent Picks (Pinned at top, up to 5)
                    if searchText.isEmpty && !recentExercises.isEmpty {
                        Section {
                            ForEach(recentExercises.prefix(5)) { exercise in
                                exerciseRow(exercise, isRecent: true)
                            }
                        } header: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(Theme.Typography.caption)
                                Text(L10n.t("最近选择", "Recent Picks"))
                                    .font(Theme.Typography.label)
                            }
                            .foregroundStyle(Theme.Colors.textMuted)
                        }
                        .listRowBackground(Theme.Colors.surfaceRaised)
                    }

                    // 2. Categorized Exercise Groups
                    ForEach(groupedExercises, id: \.0) { group, exercises in
                        Section {
                            ForEach(exercises) { exercise in
                                exerciseRow(exercise, isRecent: false)
                            }
                        } header: {
                            Text(group.displayName)
                                .font(Theme.Typography.label)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        .listRowBackground(Theme.Colors.surfaceRaised)
                    }
                }
                .scrollContentBackground(.hidden)
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: L10n.t("搜索动作（如：引体向上、推举）", "Search exercises (e.g. Pull-Up, OHP)")
                )
            }
            .navigationTitle(L10n.t("选择榜单动作", "Select Exercise"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("取消", "Cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: Exercise, isRecent: Bool) -> some View {
        Button {
            saveRecentPick(exercise.id)
            onSelect(exercise)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                    Text(exercise.primaryName)
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(exercise.secondaryName)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                Spacer()

                Text(exercise.equipment.displayName)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs / 2)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                            .fill(Theme.Colors.surfaceSunken)
                    )
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(.plain)
    }

    private func saveRecentPick(_ id: UUID) {
        var recents = recentExerciseIDs.filter { $0 != id }
        recents.insert(id, at: 0)
        let trimmed = Array(recents.prefix(5))
        recentExerciseIDsRaw = trimmed.map(\.uuidString).joined(separator: ",")
    }
}
