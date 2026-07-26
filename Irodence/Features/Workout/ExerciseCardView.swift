import SwiftUI

/// One exercise inside the active workout: header + editable set rows.
///
/// Views reach into `WorkoutManager.exercises` by INDEX. When the workout
/// finishes (or an exercise is removed), the array shrinks while SwiftUI may
/// still evaluate this subtree for one more pass — so every subscript goes
/// through a bounds check and out-of-date rows render as nothing.
struct ExerciseCardView: View {
    @EnvironmentObject private var manager: WorkoutManager
    let exerciseIndex: Int

    private var exercise: WorkoutManager.ActiveExercise? {
        manager.exercises[safe: exerciseIndex]
    }

    var body: some View {
        if let exercise {
            cardContent(exercise)
        }
    }

    @ViewBuilder
    private func cardContent(_ exercise: WorkoutManager.ActiveExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(exercise)
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

    private func header(_ exercise: WorkoutManager.ActiveExercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exercise.primaryName).font(.headline)
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
        let mode = exercise?.exercise.trackingMode ?? .weighted
        return HStack(spacing: 8) {
            Text("组").frame(width: 32)
            Text("上次").frame(width: 64)
            switch mode {
            case .weighted:
                Text("kg").frame(maxWidth: .infinity)
                Text("次数").frame(maxWidth: .infinity)
            case .bodyweight:
                Text("次数").frame(maxWidth: .infinity)
            case .duration:
                Text("时长").frame(maxWidth: .infinity)
            }
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

    private var set: WorkoutManager.ActiveSet? {
        manager.exercises[safe: exerciseIndex]?.sets[safe: setIndex]
    }

    private var mode: TrackingMode {
        manager.exercises[safe: exerciseIndex]?.exercise.trackingMode ?? .weighted
    }

    var body: some View {
        if let set {
            row(set)
        }
    }

    @ViewBuilder
    private func row(_ set: WorkoutManager.ActiveSet) -> some View {
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
            Text(previousText(set))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 64)

            switch mode {
            case .weighted:
                TextField(set.prevWeight.map { formatKg($0) } ?? "kg", text: weightBinding)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                repsField(set)
            case .bodyweight:
                repsField(set)
            case .duration:
                durationField(set)
            }

            TextField("–", text: rpeBinding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 44, height: 32)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Complete / delete
            if set.syncFailed {
                Button {
                    Task { await manager.retrySetSync(exerciseIndex: exerciseIndex, setID: set.id) }
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 32)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    manager.completeSet(exerciseIndex: exerciseIndex, setID: set.id)
                } label: {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(set.isCompleted ? .green : .secondary)
                        .frame(width: 32)
                        .scaleEffect(set.isCompleted ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: set.isCompleted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .opacity(set.isCompleted ? 0.7 : 1)
        .animation(.easeInOut(duration: 0.25), value: set.isCompleted)
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
        guard let sets = manager.exercises[safe: exerciseIndex]?.sets else { return setIndex + 1 }
        return sets
            .prefix(setIndex + 1)
            .filter { !$0.isWarmup }
            .count
    }

    private func previousText(_ set: WorkoutManager.ActiveSet) -> String {
        switch mode {
        case .weighted:
            guard let w = set.prevWeight, let r = set.prevReps else { return "—" }
            return "\(formatKg(w))×\(r)"
        case .bodyweight:
            guard let r = set.prevReps else { return "—" }
            return "×\(r)"
        case .duration:
            guard let d = set.prevDuration else { return "—" }
            return WorkoutManager.ActiveSet.formatDuration(d)
        }
    }

    private func repsField(_ set: WorkoutManager.ActiveSet) -> some View {
        TextField(set.prevReps.map(String.init) ?? "0", text: repsBinding)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    /// Stopwatch + duration entry for timed exercises (planks, cardio).
    /// While the timer runs the field shows live elapsed time; stopping the
    /// timer writes the elapsed seconds into the field for editing.
    @ViewBuilder
    private func durationField(_ set: WorkoutManager.ActiveSet) -> some View {
        HStack(spacing: 4) {
            Button {
                manager.toggleSetTimer(exerciseIndex: exerciseIndex, setID: set.id)
            } label: {
                Image(systemName: set.timerStartedAt != nil ? "stop.circle.fill" : "play.circle")
                    .font(.title3)
                    .foregroundStyle(set.timerStartedAt != nil ? .red : .accentColor)
                    .frame(width: 32)
            }
            .buttonStyle(.plain)

            if let started = set.timerStartedAt {
                TimelineView(.periodic(from: started, by: 1)) { context in
                    Text(WorkoutManager.ActiveSet.formatDuration(
                        max(0, Int(context.date.timeIntervalSince(started)))
                    ))
                    .font(.body.monospacedDigit())
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            } else {
                TextField(
                    set.prevDuration.map(WorkoutManager.ActiveSet.formatDuration) ?? "0:00",
                    text: durationBinding
                )
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    // Bindings reach into the manager's published array by index; both the
    // read and the write are bounds-checked so a stale row can't trap.
    private var weightBinding: Binding<String> {
        fieldBinding(\.weight)
    }
    private var repsBinding: Binding<String> {
        fieldBinding(\.reps)
    }
    private var durationBinding: Binding<String> {
        fieldBinding(\.duration)
    }
    private var rpeBinding: Binding<String> {
        fieldBinding(\.rpe)
    }

    private func fieldBinding(_ keyPath: WritableKeyPath<WorkoutManager.ActiveSet, String>) -> Binding<String> {
        Binding(
            get: { manager.exercises[safe: exerciseIndex]?.sets[safe: setIndex]?[keyPath: keyPath] ?? "" },
            set: { newValue in
                guard manager.exercises.indices.contains(exerciseIndex),
                      manager.exercises[exerciseIndex].sets.indices.contains(setIndex)
                else { return }
                manager.exercises[exerciseIndex].sets[setIndex][keyPath: keyPath] = newValue
            }
        )
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

extension Collection {
    /// Returns nil instead of trapping when the index is out of bounds.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
