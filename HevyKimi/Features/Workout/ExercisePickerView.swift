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
            List(filtered) { exercise in
                Button {
                    toggle(exercise.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.nameZh).font(.headline)
                            Text("\(exercise.primaryMuscle.displayName) · \(exercise.equipment.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selected.contains(exercise.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .tint(.primary)
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
