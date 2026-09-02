import SwiftUI

/// Live workout logging screen: exercise cards, set entry, rest timer HUD, and in-workout PR 铁证 hooks.
struct ActiveWorkoutView: View {
    @EnvironmentObject private var manager: WorkoutManager
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    private enum ActiveWorkoutAlert: Identifiable {
        case finishConfirm
        case discardConfirm
        case templatePrompt
        case emptySetsWarning

        var id: Int {
            switch self {
            case .finishConfirm: return 1
            case .discardConfirm: return 2
            case .templatePrompt: return 3
            case .emptySetsWarning: return 4
            }
        }
    }

    @State private var activeAlert: ActiveWorkoutAlert?
    @State private var showExercisePicker = false
    @State private var templateName = ""
    @State private var proofToSubmit: WorkoutManager.PRPrompt?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                exerciseList

                // Bottom Floating Overlay: PR "上铁证" Banner + Rest Timer HUD
                VStack(spacing: Theme.Spacing.sm) {
                    if let pr = manager.currentPRPrompt {
                        prCelebrationBanner(pr)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if manager.restEndsAt != nil {
                        RestTimerView(
                            restEndsAt: $manager.restEndsAt,
                            duration: $manager.restDurationSeconds,
                            nextTarget: nextTargetPreview
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
            }
            .animation(.spring(duration: 0.35), value: manager.restEndsAt != nil)
            .animation(.spring(duration: 0.35), value: manager.currentPRPrompt != nil)
            .background(Theme.Colors.surfaceBase.ignoresSafeArea())
            .navigationTitle(manager.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(manager.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        ElapsedTimeView(startedAt: manager.startedAt)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            templateName = manager.name
                            activeAlert = .templatePrompt
                        } label: {
                            Label(L10n.t("保存为模板", "Save as Template"), systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive) {
                            activeAlert = .discardConfirm
                        } label: {
                            Label(L10n.t("放弃训练", "Discard Workout"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("完成", "Finish")) {
                        handleFinishTap()
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { selected in
                    Task {
                        for exercise in selected {
                            await manager.addExercise(exercise)
                        }
                    }
                }
            }
            .sheet(item: $proofToSubmit) { pr in
                SubmitProofSheet(
                    userID: manager.userID,
                    exercise: pr.exercise,
                    weightKg: pr.weightKg,
                    reps: pr.reps,
                    estimated1RM: pr.estimated1RM,
                    previousBest1RM: pr.previousBest1RM,
                    onSubmitted: {
                        manager.currentPRPrompt = nil
                    }
                )
            }
            .alert(item: $activeAlert) { alertType in
                switch alertType {
                case .finishConfirm:
                    return Alert(
                        title: Text(L10n.t("完成训练？", "Finish Workout?")),
                        message: Text(L10n.t("将保存本次训练并计算力量分与新纪录", "Saves this workout and computes updated strength scores & PRs.")),
                        primaryButton: .default(Text(L10n.t("完成并保存", "Finish & Save"))) {
                            Task {
                                let finished = await manager.finish()
                                if !finished {
                                    activeAlert = .emptySetsWarning
                                }
                            }
                        },
                        secondaryButton: .cancel(Text(L10n.t("取消", "Cancel")))
                    )
                case .discardConfirm:
                    return Alert(
                        title: Text(L10n.t("放弃本次训练？", "Discard Workout?")),
                        message: Text(L10n.t("已记录的数据将被删除", "All logged data for this workout will be deleted.")),
                        primaryButton: .destructive(Text(L10n.t("放弃并删除", "Discard & Delete"))) {
                            Task { await manager.discard() }
                        },
                        secondaryButton: .cancel(Text(L10n.t("取消", "Cancel")))
                    )
                case .emptySetsWarning:
                    return Alert(
                        title: Text(L10n.t("暂无已完成的组数", "No Completed Sets")),
                        message: Text(L10n.t("尚未打勾完成任何组数，是否直接放弃退出？", "No sets were completed. Discard workout or continue?")),
                        primaryButton: .destructive(Text(L10n.t("放弃退出", "Discard & Exit"))) {
                            Task { await manager.discard() }
                        },
                        secondaryButton: .cancel(Text(L10n.t("继续训练", "Continue")))
                    )
                case .templatePrompt:
                    return Alert(
                        title: Text(L10n.t("保存为模板", "Save as Template")),
                        message: Text(L10n.t("将当前动作与组数保存为自定义模板", "Save current routine as a custom template.")),
                        primaryButton: .default(Text(L10n.t("保存", "Save"))) {
                            Task { await manager.saveAsTemplate(templateName: templateName) }
                        },
                        secondaryButton: .cancel(Text(L10n.t("取消", "Cancel")))
                    )
                }
            }
        }
    }

    private func handleFinishTap() {
        manager.autoCompleteFilledSets()
        let hasCompleted = manager.exercises.flatMap(\.sets).contains(where: \.isCompleted)
        if hasCompleted {
            activeAlert = .finishConfirm
        } else {
            activeAlert = .emptySetsWarning
        }
    }

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(Array(manager.exercises.enumerated()), id: \.element.id) { index, _ in
                    ExerciseCardView(exerciseIndex: index)
                }

                // Add Exercise Button (Subdued)
                Button {
                    showExercisePicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                        Text(L10n.t("添加动作", "Add Exercise"))
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .fill(Theme.Colors.surfaceRaised)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.md)

                if let error = manager.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.Colors.rust)
                        .padding(.horizontal, Theme.Spacing.md)
                }

                // Bottom Primary Finish Action (One-handed reach)
                Button {
                    handleFinishTap()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20, weight: .bold))
                        Text(L10n.t("完成训练", "Finish Workout"))
                            .font(.system(size: 19, weight: .bold))
                    }
                    .foregroundStyle(Theme.Colors.emberDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .fill(Theme.Colors.ember)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)

                // Spacer for bottom HUD / Rest Timer room
                Color.clear.frame(height: 120)
            }
            .padding(.vertical, Theme.Spacing.md)
        }
    }

    private func prCelebrationBanner(_ pr: WorkoutManager.PRPrompt) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.ember.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(L10n.t("突破历史 1RM!", "New 1RM PR!"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.Colors.ember)
                    Text("\(pr.exercise.primaryName)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                Text(L10n.t("\(formatKg(pr.weightKg))kg × \(pr.reps) (预估 1RM: \(formatKg(pr.estimated1RM))kg)", "\(formatKg(pr.weightKg))kg × \(pr.reps) (Est. 1RM: \(formatKg(pr.estimated1RM))kg)"))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            Button {
                proofToSubmit = pr
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(L10n.t("上铁证", "Submit Proof"))
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(Theme.Colors.emberDeep)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(Theme.Colors.ember)
                )
            }
            .buttonStyle(.plain)

            Button {
                withAnimation { manager.currentPRPrompt = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.ember, lineWidth: Theme.Border.certified)
        )
        .shadow(color: Color.black.opacity(0.6), radius: 12, y: 4)
    }

    private var nextTargetPreview: String? {
        for ex in manager.exercises {
            for set in ex.sets {
                if !set.isCompleted {
                    if let w = set.parsedWeight, let r = set.parsedReps {
                        return "\(ex.exercise.primaryName) \(formatKg(w))kg × \(r)"
                    } else if let r = set.parsedReps {
                        return "\(ex.exercise.primaryName) \(r)"
                    } else {
                        return ex.exercise.primaryName
                    }
                }
            }
        }
        return nil
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

/// Live-updating elapsed time in the nav bar.
private struct ElapsedTimeView: View {
    let startedAt: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(format(context.date))
        }
    }

    private func format(_ now: Date) -> String {
        guard let startedAt else { return "" }
        let elapsed = Int(now.timeIntervalSince(startedAt))
        let h = elapsed / 3600, m = (elapsed % 3600) / 60, s = elapsed % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}
