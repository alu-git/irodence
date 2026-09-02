import SwiftUI

/// Expanded view of one feed workout: every exercise with its full set list
/// (weight × reps), per-exercise volume share, top set 1RM highlights, and a muscle split summary.
struct WorkoutDetailView: View {
    let item: FeedItem
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    @State private var currentName: String = ""
    @State private var showRenameAlert = false
    @State private var newNameInput = ""
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    private let workoutService = WorkoutService()

    init(item: FeedItem) {
        self.item = item
        _currentName = State(initialValue: item.name)
        _newNameInput = State(initialValue: item.name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header
                statsRow
                muscleSplitBar

                ForEach(item.exercises) { exercise in
                    exerciseSection(exercise)
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.surfaceBase.ignoresSafeArea())
        .navigationTitle(currentName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        newNameInput = currentName
                        showRenameAlert = true
                    } label: {
                        Label(L10n.t("修改训练名称", "Rename Workout"), systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label(L10n.t("删除此训练", "Delete Workout"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .alert(L10n.t("修改训练名称", "Rename Workout"), isPresented: $showRenameAlert) {
            TextField(L10n.t("训练名称", "Workout Name"), text: $newNameInput)
            Button(L10n.t("取消", "Cancel"), role: .cancel) { }
            Button(L10n.t("保存", "Save")) {
                let name = newNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    currentName = name
                    Task { try? await workoutService.updateWorkoutName(item.id, name: name) }
                }
            }
        }
        .alert(L10n.t("确认删除此训练？", "Delete Workout?"), isPresented: $showDeleteConfirm) {
            Button(L10n.t("取消", "Cancel"), role: .cancel) { }
            Button(L10n.t("删除", "Delete"), role: .destructive) {
                Task {
                    isDeleting = true
                    try? await workoutService.discardWorkout(item.id)
                    dismiss()
                }
            }
        } message: {
            Text(L10n.t("删除后此训练数据将无法恢复", "This workout record will be permanently deleted."))
        }
    }

    /// Who + when — taps through to their profile.
    private var header: some View {
        NavigationLink(value: FeedDestination.profile(userID: item.userID,
                                                      displayName: item.displayName)) {
            HStack(spacing: Theme.Spacing.sm) {
                AvatarView(name: item.displayName, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(item.relativeTimeText)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(item.durationText, L10n.t("时长", "Time"), "clock")
            stat(item.volumeText, L10n.t("容量", "Volume"), "scalemass")
            stat("\(item.setCount)", L10n.t("组数", "Sets"), "checkmark.circle")
        }
        .padding(.vertical, 12)
        .background(Theme.Colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    private func stat(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Label(value, systemImage: icon)
                .font(Theme.Typography.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .labelStyle(.titleAndIcon)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 2. Compact Muscle Split Bar

    private struct MuscleSplitItem {
        let name: String
        let percentage: Double
        let color: Color
    }

    private var muscleSplitBar: some View {
        let splits = calculateMuscleSplits()
        return Group {
            if !splits.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(splits, id: \.name) { split in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(split.color)
                                    .frame(width: 6, height: 6)
                                Text("\(split.name) \(Int(round(split.percentage * 100)))%")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.surfaceSunken, in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                            )
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    private func calculateMuscleSplits() -> [MuscleSplitItem] {
        guard !item.exercises.isEmpty else { return [] }
        var muscleSets: [String: Int] = [:]
        var totalSets = 0

        for ex in item.exercises {
            let muscleName = ex.primaryMuscle.displayName
            let sets = ex.sets.filter { !$0.isWarmup }.count
            let count = sets > 0 ? sets : ex.setCount
            muscleSets[muscleName, default: 0] += count
            totalSets += count
        }

        guard totalSets > 0 else { return [] }

        let colors: [Color] = [
            Theme.Colors.ember,
            Theme.Colors.tierRefinedSteel,
            Theme.Colors.tierHundredFold,
            Theme.Colors.textSecondary
        ]

        let sorted = muscleSets.sorted { $0.value > $1.value }
        return sorted.enumerated().map { index, entry in
            MuscleSplitItem(
                name: entry.key,
                percentage: Double(entry.value) / Double(totalSets),
                color: colors[index % colors.count]
            )
        }
    }

    // MARK: - Exercise Section with Volume Share & Top Set 1RM

    private func exerciseSection(_ exercise: FeedExerciseSummary) -> some View {
        let topSetIdx = topSetIndex(in: exercise)
        let share = item.totalVolumeKg > 0 ? (exercise.volumeKg / item.totalVolumeKg) : 0

        return VStack(alignment: .leading, spacing: 10) {
            // Exercise Header
            HStack(spacing: 10) {
                MiniMuscleDiagram(primary: exercise.muscles.primary,
                                  secondary: exercise.muscles.secondary)
                    .frame(width: 30, height: 40)
                    .clipped()

                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.displayName)
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    HStack(spacing: 5) {
                        Text("\(exercise.setCount) \(L10n.t("组", "sets")) · \(volumeText(exercise.volumeKg))")
                            .font(Theme.Typography.caption.monospacedDigit())
                            .foregroundStyle(Theme.Colors.textSecondary)

                        if item.totalVolumeKg > 0 && share > 0.05 {
                            Text("· \(Int(round(share * 100)))% \(L10n.t("容量", "vol"))")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.ember)
                        }
                    }
                }
                Spacer()
            }

            // 4. Hairline Volume Share Indicator
            if share > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.Colors.surfaceSunken)
                        Capsule()
                            .fill(Theme.Colors.ember.opacity(0.85))
                            .frame(width: max(geo.size.width * CGFloat(share), 4))
                    }
                }
                .frame(height: 2)
            }

            // Set list: index, weight × reps, plus Top Set 1RM on the right
            VStack(spacing: 4) {
                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                    HStack(spacing: 12) {
                        Text(set.isWarmup ? L10n.t("热身", "W") : "\(workingSetIndex(upTo: index, in: exercise))")
                            .font(Theme.Typography.caption.monospacedDigit())
                            .foregroundStyle(Theme.Colors.textMuted)
                            .frame(width: 28, alignment: .center)

                        Text("\(set.weightText) kg × \(set.reps)")
                            .font(Theme.Typography.body.monospacedDigit())
                            .foregroundStyle(set.isWarmup ? Theme.Colors.textMuted : Theme.Colors.textPrimary)

                        Spacer()

                        // 1. Top Set / Estimated 1RM Tag
                        if index == topSetIdx && !set.isWarmup && set.weightKg > 0 {
                            let est1RM = set.weightKg * (1.0 + Double(set.reps) / 30.0)
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 8.5))
                                Text(L10n.t("最佳 1RM \(Int(round(est1RM)))kg", "Top 1RM \(Int(round(est1RM)))kg"))
                                    .font(Theme.Typography.caption)
                            }
                            .foregroundStyle(Theme.Colors.ember)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.ember.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .background(Theme.Colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    /// Finds the set with the highest estimated 1RM in an exercise.
    private func topSetIndex(in exercise: FeedExerciseSummary) -> Int? {
        var max1RM: Double = 0
        var topIdx: Int? = nil
        for (idx, set) in exercise.sets.enumerated() {
            guard !set.isWarmup, set.weightKg > 0, set.reps > 0 else { continue }
            let est = set.weightKg * (1.0 + Double(set.reps) / 30.0)
            if est > max1RM {
                max1RM = est
                topIdx = idx
            }
        }
        return topIdx
    }

    /// 1-based index among non-warmup sets only.
    private func workingSetIndex(upTo index: Int, in exercise: FeedExerciseSummary) -> Int {
        exercise.sets.prefix(through: index).filter { !$0.isWarmup }.count
    }

    private func volumeText(_ kg: Double) -> String {
        kg >= 1000
            ? String(format: "%.1fk kg", kg / 1000)
            : "\(Int(kg)) kg"
    }
}
