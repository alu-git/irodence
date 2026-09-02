import SwiftUI

/// Exercise picker presented while logging. Multi-select, searchable, filterable by muscle group.
struct ExercisePickerView: View {
    @EnvironmentObject private var library: ExerciseService
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    let onAdd: ([Exercise]) -> Void

    @State private var query = ""
    @State private var selected: Set<UUID> = []
    @State private var selectedMuscle: MuscleGroup? = nil
    @State private var selectedDetailExercise: Exercise? = nil

    // Exercises after applying muscle filter + text search
    private var filtered: [Exercise] {
        let base = selectedMuscle.map { mg in
            library.exercises.filter { $0.primaryMuscle == mg }
        } ?? library.exercises

        guard !query.isEmpty else { return base }
        let q = query.lowercased()
        return base.filter {
            $0.nameZh.contains(query) || $0.nameEn.lowercased().contains(q)
        }
    }

    // Grouped list respecting the muscle filter
    private var filteredGrouped: [(muscle: MuscleGroup, exercises: [Exercise])] {
        if let mg = selectedMuscle {
            let list = library.exercises
                .filter { $0.primaryMuscle == mg }
                .sorted { $0.primaryName < $1.primaryName }
            return list.isEmpty ? [] : [(muscle: mg, exercises: list)]
        }
        return library.grouped
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MuscleFilterBar(selected: $selectedMuscle)
                Divider()
                listContent
            }
            .navigationTitle(L10n.t("添加动作", "Add Exercise"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: L10n.t("搜索动作", "Search exercises…"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("取消", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("添加 (\(selected.count))", "Add (\(selected.count))")) {
                        let picked = library.exercises.filter { selected.contains($0.id) }
                        onAdd(picked)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .task { await library.loadIfNeeded() }
            .sheet(item: $selectedDetailExercise) { exercise in
                NavigationStack {
                    ExerciseDetailView(exercise: exercise)
                }
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        // No filter active and no query → grouped view
        if query.isEmpty && selectedMuscle == nil {
            List {
                ForEach(filteredGrouped, id: \.muscle) { group in
                    Section(group.muscle.displayName) {
                        ForEach(group.exercises) { exercise in
                            PickerRow(
                                exercise: exercise,
                                isSelected: selected.contains(exercise.id),
                                onTap: { toggle(exercise.id) },
                                onInfoTap: { selectedDetailExercise = exercise }
                            )
                        }
                    }
                }
            }
        } else if filtered.isEmpty {
            // Empty state (iOS 16 compatible)
            ComingSoonView(
                title: L10n.t("没有符合条件的动作", "No Matching Exercises"),
                systemImage: "magnifyingglass",
                subtitle: L10n.t("换个关键词或肌群试试", "Try a different keyword or muscle group")
            )
        } else if selectedMuscle != nil && query.isEmpty {
            // Muscle-only filter → keep muscle section
            List {
                ForEach(filteredGrouped, id: \.muscle) { group in
                    Section(group.muscle.displayName) {
                        ForEach(group.exercises) { exercise in
                            PickerRow(
                                exercise: exercise,
                                isSelected: selected.contains(exercise.id),
                                onTap: { toggle(exercise.id) },
                                onInfoTap: { selectedDetailExercise = exercise }
                            )
                        }
                    }
                }
            }
        } else {
            // Text search (± muscle filter) → flat list
            List(filtered) { exercise in
                PickerRow(
                    exercise: exercise,
                    isSelected: selected.contains(exercise.id),
                    onTap: { toggle(exercise.id) },
                    onInfoTap: { selectedDetailExercise = exercise }
                )
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }
}

// MARK: - Selectable row

private struct PickerRow: View {
    let exercise: Exercise
    let isSelected: Bool
    let onTap: () -> Void
    let onInfoTap: () -> Void
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    var body: some View {
        HStack {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.displayName).font(.headline)
                        Text("\(exercise.primaryMuscle.displayName) · \(exercise.equipment.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button(action: onInfoTap) {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.plain)

            Button(action: onTap) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
                    .font(.title3)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
            }
            .buttonStyle(.plain)
        }
    }
}
