import SwiftUI

/// One exercise inside the active workout: header + editable set rows.
struct ExerciseCardView: View {
    @EnvironmentObject private var manager: WorkoutManager
    let exerciseIndex: Int

    private var exercise: WorkoutManager.ActiveExercise {
        manager.exercises[exerciseIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            setHeader
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, set in
                SetRowView(exerciseIndex: exerciseIndex, setIndex: setIndex)
                if setIndex < exercise.sets.count - 1 {
                    Divider().padding(.leading, 12)
                }
            }
            Button {
                manager.addSet(to: exerciseIndex)
            } label: {
                Label("添加组", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exercise.nameZh).font(.headline)
                if let group = exercise.supersetGroup {
                    Label("超级组 \(supersetLetter(group))", systemImage: "link")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Menu {
                if exerciseIndex > 0, exercise.supersetGroup == nil {
                    Button {
                        Task { await manager.supersetWithPrevious(at: exerciseIndex) }
                    } label: {
                        Label("与上一动作组成超级组", systemImage: "link")
                    }
                }
                if exercise.supersetGroup != nil {
                    Button {
                        Task { await manager.removeFromSuperset(at: exerciseIndex) }
                    } label: {
                        Label("取消超级组", systemImage: "link.badge.plus")
                    }
                }
                Button(role: .destructive) {
                    Task { await manager.removeExercise(at: exerciseIndex) }
                } label: {
                    Label("移除动作", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .padding(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    private var setHeader: some View {
        HStack(spacing: 8) {
            Text("组").frame(width: 32)
            Text("上次").frame(width: 64)
            Text("kg").frame(maxWidth: .infinity)
            Text("次数").frame(maxWidth: .infinity)
            Text("RPE").frame(width: 44)
            Text("").frame(width: 32)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
    }

    private func supersetLetter(_ group: Int) -> String {
        String(UnicodeScalar(64 + group).map(Character.init) ?? "?")
    }
}

/// A single set row: previous-session placeholder + editable fields.
struct SetRowView: View {
    @EnvironmentObject private var manager: WorkoutManager
    let exerciseIndex: Int
    let setIndex: Int

    private var set: WorkoutManager.ActiveSet {
        manager.exercises[exerciseIndex].sets[setIndex]
    }

    var body: some View {
        HStack(spacing: 8) {
            // Set number / warmup toggle
            Button {
                Task { await manager.toggleWarmup(exerciseIndex: exerciseIndex, setID: set.id) }
            } label: {
                Text(set.isWarmup ? "热身" : "\(workingSetNumber)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .frame(width: 32, height: 28)
                    .background(set.isWarmup ? Color.orange.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .foregroundStyle(set.isWarmup ? .orange : .secondary)

            // Previous session placeholder
            Text(previousText)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 64)

            TextField(set.prevWeight.map { formatKg($0) } ?? "kg", text: weightBinding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            TextField(set.prevReps.map(String.init) ?? "0", text: repsBinding)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            TextField("–", text: rpeBinding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 44, height: 32)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Complete / delete
            Button {
                Task { await manager.completeSet(exerciseIndex: exerciseIndex, setID: set.id) }
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.title3)
                    .foregroundStyle(set.isCompleted ? .green : .secondary)
                    .frame(width: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .opacity(set.isCompleted ? 0.7 : 1)
        .swipeActionsCompat {
            if !set.isCompleted {
                Button(role: .destructive) {
                    Task { await manager.deleteSet(exerciseIndex: exerciseIndex, setID: set.id) }
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }

    /// Working sets are numbered skipping warmups, like Hevy does.
    private var workingSetNumber: Int {
        manager.exercises[exerciseIndex].sets
            .prefix(setIndex + 1)
            .filter { !$0.isWarmup }
            .count
    }

    private var previousText: String {
        guard let w = set.prevWeight, let r = set.prevReps else { return "—" }
        return "\(formatKg(w))×\(r)"
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    // Bindings reach into the manager's published array by index.
    private var weightBinding: Binding<String> {
        $manager.exercises[exerciseIndex].sets[setIndex].weight
    }
    private var repsBinding: Binding<String> {
        $manager.exercises[exerciseIndex].sets[setIndex].reps
    }
    private var rpeBinding: Binding<String> {
        $manager.exercises[exerciseIndex].sets[setIndex].rpe
    }
}

/// swipeActions only works inside List; this is a no-op shim for ScrollView rows
/// so the modifier name reads the same if we later move to List.
private extension View {
    @ViewBuilder
    func swipeActionsCompat<Content: View>(@ViewBuilder actions: () -> Content) -> some View {
        self
    }
}
