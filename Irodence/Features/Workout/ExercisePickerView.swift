import SwiftUI

/// Exercise picker presented while logging. Multi-select, searchable.
struct ExercisePickerView: View {
    @EnvironmentObject private var library: ExerciseService
    @Environment(\.dismiss) private var dismiss

    let onAdd: ([Exercise]) -> Void

    @State private var query = ""
    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    // Grouped by muscle group, like the library tab
                    List {
                        ForEach(library.grouped, id: \.muscle) { group in
                            Section(group.muscle.displayName) {
                                ForEach(group.exercises) { exercise in
                                    PickerRow(exercise: exercise,
                                              isSelected: selected.contains(exercise.id)) {
                                        toggle(exercise.id)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    List(filtered) { exercise in
                        PickerRow(exercise: exercise,
                                  isSelected: selected.contains(exercise.id)) {
                            toggle(exercise.id)
                        }
                    }
                }
            }
            .navigationTitle("添加动作")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "搜索动作")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加 (\(selected.count))") {
                        let picked = library.exercises.filter { selected.contains($0.id) }
                        onAdd(picked)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .task { await library.loadIfNeeded() }
        }
    }

    private var filtered: [Exercise] {
        library.search(query)
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }
}

/// One selectable exercise row in the picker.
private struct PickerRow: View {
    let exercise: Exercise
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.displayName).font(.headline)
                    Text("\(exercise.primaryMuscle.displayName) · \(exercise.equipment.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .tint(.primary)
    }
}
