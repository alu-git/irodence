import SwiftUI

/// One exercise inside the active workout: header + editable set rows.
/// Follows IRODENCE_DESIGN.md visual discipline:
/// - Active set receives 3.5pt ember left edge & raised surface.
/// - Completed sets are dimmed with filled ember check.
/// - Future sets stay flat with subtle border.
/// - Gym-grade, high-contrast, bold typography readable from a distance.
struct ExerciseCardView: View {
    @EnvironmentObject private var manager: WorkoutManager
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue
    let exerciseIndex: Int

    @State private var showDetail = false

    private var exercise: WorkoutManager.ActiveExercise? {
        manager.exercises[safe: exerciseIndex]
    }

    private var hasPreviousHistory: Bool {
        guard let exercise else { return false }
        return !exercise.previousSets.isEmpty || exercise.sets.contains { $0.prevWeight != nil || $0.prevReps != nil || $0.prevDuration != nil }
    }

    var body: some View {
        if let exercise {
            cardContent(exercise)
                .sheet(isPresented: $showDetail) {
                    NavigationStack {
                        ExerciseDetailView(exercise: exercise.exercise)
                    }
                }
        }
    }

    @ViewBuilder
    private func cardContent(_ exercise: WorkoutManager.ActiveExercise) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm + 2) {
            header(exercise)
            setHeader(hasHistory: hasPreviousHistory)

            VStack(spacing: 8) {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, _ in
                    SetRowView(
                        exerciseIndex: exerciseIndex,
                        setIndex: setIndex,
                        showPreviousColumn: hasPreviousHistory
                    )
                }
            }

            // Subdued Add Set Button (Ember scarcity enforced, large touch target)
            Button {
                manager.addSet(to: exerciseIndex)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                    Text(L10n.t("添加组", "Add Set"))
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(Theme.Colors.surfaceSunken)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    private func header(_ exercise: WorkoutManager.ActiveExercise) -> some View {
        HStack {
            Text(exercise.exercise.primaryName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            if let group = exercise.supersetGroup {
                Text(L10n.t("超级组 \(supersetLetter(group))", "Superset \(supersetLetter(group))"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))
            }

            Spacer()

            Menu {
                Button {
                    showDetail = true
                } label: {
                    Label(L10n.t("查看动作详情", "View Exercise Details"), systemImage: "info.circle")
                }
                if exerciseIndex > 0, exercise.supersetGroup == nil {
                    Button {
                        Task { await manager.supersetWithPrevious(at: exerciseIndex) }
                    } label: {
                        Label(L10n.t("与上一动作组成超级组", "Superset with Previous"), systemImage: "link")
                    }
                }
                if exercise.supersetGroup != nil {
                    Button {
                        Task { await manager.removeFromSuperset(at: exerciseIndex) }
                    } label: {
                        Label(L10n.t("取消超级组", "Remove Superset"), systemImage: "link.badge.plus")
                    }
                }
                Button(role: .destructive) {
                    Task { await manager.removeExercise(at: exerciseIndex) }
                } label: {
                    Label(L10n.t("移除动作", "Remove Exercise"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(8)
            }
        }
    }

    private func setHeader(hasHistory: Bool) -> some View {
        let mode = exercise?.exercise.trackingMode ?? .weighted
        return HStack(spacing: 8) {
            Text(L10n.t("组", "Set")).frame(width: 44)
            if hasHistory {
                Text(L10n.t("上次", "Prev")).frame(width: 76)
            }
            switch mode {
            case .weighted:
                Text("kg").frame(maxWidth: .infinity)
                Text(L10n.t("次", "Reps")).frame(maxWidth: .infinity)
            case .bodyweight:
                Text(L10n.t("次数", "Reps")).frame(maxWidth: .infinity)
            case .duration:
                Text(L10n.t("时长", "Time")).frame(maxWidth: .infinity)
            }
            Text("RPE").frame(width: 48)
            Text("").frame(width: 40)
        }
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(Theme.Colors.textSecondary)
        .padding(.horizontal, 4)
    }

    private func supersetLetter(_ group: Int) -> String {
        String(UnicodeScalar(64 + group).map(Character.init) ?? "?")
    }
}

/// A gym-proof single set row:
/// - 48pt touch targets for chalked fingers
/// - Active set ember indicator bar
/// - Big, bold high-contrast fonts
/// - Ghosted previous-session numbers as tap-to-accept placeholders
struct SetRowView: View {
    @EnvironmentObject private var manager: WorkoutManager
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue
    let exerciseIndex: Int
    let setIndex: Int
    let showPreviousColumn: Bool

    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepsFocused: Bool
    @State private var showPlateChips = false

    private var set: WorkoutManager.ActiveSet? {
        manager.exercises[safe: exerciseIndex]?.sets[safe: setIndex]
    }

    private var mode: TrackingMode {
        manager.exercises[safe: exerciseIndex]?.exercise.trackingMode ?? .weighted
    }

    private var isActive: Bool {
        manager.isActiveSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
    }

    var body: some View {
        if let set {
            VStack(spacing: 6) {
                mainRow(set)

                // Quick Plate Increments Bar when active & weighted
                if isActive && mode == .weighted && !set.isCompleted && (isWeightFocused || showPlateChips) {
                    plateToolbar
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isWeightFocused || showPlateChips)
        }
    }

    @ViewBuilder
    private func mainRow(_ set: WorkoutManager.ActiveSet) -> some View {
        HStack(spacing: 8) {
            // Set number / Warmup toggle
            Button {
                ForgeHaptics.selection()
                Task { await manager.toggleWarmup(exerciseIndex: exerciseIndex, setID: set.id) }
            } label: {
                Text(set.isWarmup ? "W" : "\(workingSetNumber)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(set.isWarmup ? Theme.Colors.ember : (isActive ? Theme.Colors.textPrimary : Theme.Colors.textSecondary))
                    .frame(width: 40, height: 48)
                    .background(set.isWarmup ? Theme.Colors.ember.opacity(0.18) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            }
            .buttonStyle(.plain)

            // Previous session placeholder column (collapsed if no history)
            if showPreviousColumn {
                Text(previousText(set))
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 72)
                    .lineLimit(1)
            }

            // Input Fields
            switch mode {
            case .weighted:
                weightField(set)
                repsField(set)
            case .bodyweight:
                repsField(set)
            case .duration:
                durationField(set)
            }

            // RPE Field
            TextField("–", text: rpeBinding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 48, height: 48)
                .background(Theme.Colors.surfaceSunken)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                )

            // Completion Action Checkmark Button
            Button {
                manager.completeSet(exerciseIndex: exerciseIndex, setID: set.id)
                ForgeHaptics.strike()
            } label: {
                ZStack {
                    if set.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.Colors.ember)
                    } else if isActive {
                        Image(systemName: "circle")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Theme.Colors.ember)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(Theme.Colors.borderMetal)
                    }
                }
                .frame(width: 40, height: 48)
                .hammerStrike(trigger: set.isCompleted)
            }
            .buttonStyle(.forgePress)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(isActive ? Theme.Colors.surfaceRaised : Theme.Colors.surfaceBase)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .strokeBorder(isActive ? Theme.Colors.borderMetal : Color.clear, lineWidth: Theme.Border.hairline)
        )
        // Left 3.5pt Ember Edge for Active Set
        .overlay(alignment: .leading) {
            if isActive {
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(Theme.Colors.ember)
                    .frame(width: 3.5)
            }
        }
        .opacity(set.isCompleted ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: set.isCompleted)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    private var plateToolbar: some View {
        HStack(spacing: 6) {
            Text(L10n.t("杠铃片", "Plates"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)
                .fixedSize()

            ForEach([-5.0, -2.5, 2.5, 5.0, 10.0, 20.0], id: \.self) { delta in
                Button {
                    manager.adjustWeight(exerciseIndex: exerciseIndex, setIndex: setIndex, deltaKg: delta)
                    ForgeHaptics.selection()
                } label: {
                    Text(delta > 0 ? "+\(formatPlate(delta))" : "\(formatPlate(delta))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(delta > 0 ? Theme.Colors.textPrimary : Theme.Colors.rust)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                }
                .buttonStyle(.platePillPress)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.Colors.surfaceBase, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
    }

    private func formatPlate(_ val: Double) -> String {
        val.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(val)) : String(format: "%.1f", val)
    }

    private var workingSetNumber: Int {
        guard let sets = manager.exercises[safe: exerciseIndex]?.sets else { return setIndex + 1 }
        return sets.prefix(setIndex + 1).filter { !$0.isWarmup }.count
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

    private func weightField(_ set: WorkoutManager.ActiveSet) -> some View {
        TextField(set.prevWeight.map { formatKg($0) } ?? "—", text: weightBinding)
            .focused($isWeightFocused)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 20, weight: .bold, design: .monospaced))
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Theme.Colors.surfaceSunken)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .strokeBorder(isWeightFocused ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: isWeightFocused ? Theme.Border.certified : Theme.Border.hairline)
            )
            .onTapGesture {
                showPlateChips.toggle()
                if set.weight.isEmpty, let prev = set.prevWeight {
                    manager.exercises[exerciseIndex].sets[setIndex].weight = formatKg(prev)
                }
            }
    }

    private func repsField(_ set: WorkoutManager.ActiveSet) -> some View {
        TextField(set.prevReps.map(String.init) ?? "—", text: repsBinding)
            .focused($isRepsFocused)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 20, weight: .bold, design: .monospaced))
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Theme.Colors.surfaceSunken)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .strokeBorder(isRepsFocused ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: isRepsFocused ? Theme.Border.certified : Theme.Border.hairline)
            )
            .onTapGesture {
                if set.reps.isEmpty, let prev = set.prevReps {
                    manager.exercises[exerciseIndex].sets[setIndex].reps = String(prev)
                }
            }
    }

    @ViewBuilder
    private func durationField(_ set: WorkoutManager.ActiveSet) -> some View {
        HStack(spacing: 4) {
            Button {
                manager.toggleSetTimer(exerciseIndex: exerciseIndex, setID: set.id)
            } label: {
                Image(systemName: set.timerStartedAt != nil ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(set.timerStartedAt != nil ? Theme.Colors.rust : Theme.Colors.textPrimary)
                    .frame(width: 36)
            }
            .buttonStyle(.plain)

            if let started = set.timerStartedAt {
                TimelineView(.periodic(from: started, by: 1)) { context in
                    Text(WorkoutManager.ActiveSet.formatDuration(
                        max(0, Int(context.date.timeIntervalSince(started)))
                    ))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.Colors.ember)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.Colors.surfaceSunken)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                }
            } else {
                TextField(
                    set.prevDuration.map(WorkoutManager.ActiveSet.formatDuration) ?? "—",
                    text: durationBinding
                )
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.center)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.Colors.surfaceSunken)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    private var weightBinding: Binding<String> { fieldBinding(\.weight) }
    private var repsBinding: Binding<String> { fieldBinding(\.reps) }
    private var durationBinding: Binding<String> { fieldBinding(\.duration) }
    private var rpeBinding: Binding<String> { fieldBinding(\.rpe) }

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

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
