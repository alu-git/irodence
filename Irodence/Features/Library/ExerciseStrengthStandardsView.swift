import SwiftUI

/// Interactive strength ranking & standards ladder for any exercise in the bank.
/// Shows the user's current tier, progress bar to the next tier, and full 6-tier
/// empirical standards table dynamically scaled to sex and bodyweight.
struct ExerciseStrengthStandardsView: View {
    let exercise: Exercise
    var user1RM: Double?

    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue
    @State private var selectedSex: Sex = .male
    @State private var selectedBodyweight: Double = 75.0

    init(exercise: Exercise, user1RM: Double? = nil, defaultSex: Sex = .male, defaultBodyweight: Double = 75.0) {
        self.exercise = exercise
        self.user1RM = user1RM
        _selectedSex = State(initialValue: defaultSex)
        _selectedBodyweight = State(initialValue: max(defaultBodyweight, 45))
    }

    private var unit: String {
        ExerciseStrengthStandards.unitLabel(for: exercise)
    }

    private var currentAchievedTier: StrengthTier {
        guard let w = user1RM, w > 0 else { return .pigIron }
        return ExerciseStrengthStandards.tier(for: w, exercise: exercise, sex: selectedSex, bodyweightKg: selectedBodyweight)
    }

    private var tierProgressData: (tier: StrengthTier, progress: Double, nextTargetKg: Double?, currentTierMinKg: Double) {
        let weight = user1RM ?? 0
        return ExerciseStrengthStandards.progress(for: weight, exercise: exercise, sex: selectedSex, bodyweightKg: selectedBodyweight)
    }

    private var ladder: [ExerciseLadderTier] {
        ExerciseStrengthStandards.ladder(for: exercise, sex: selectedSex, bodyweightKg: selectedBodyweight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)

                Text(L10n.t("力量段位标准", "Strength Standards"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()

                // Sex selector
                Picker(L10n.t("性别", "Sex"), selection: $selectedSex) {
                    Text(L10n.t("男 ♂", "Male ♂")).tag(Sex.male)
                    Text(L10n.t("女 ♀", "Female ♀")).tag(Sex.female)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            // 1. Current Tier Hero Card
            heroTierCard

            // 2. Bodyweight Interactive Selector
            bodyweightPickerRow

            // 3. 6-Tier Standards Ladder Table
            ladderTable
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    // MARK: - 1. Hero Current Tier Status

    private var heroTierCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                // Tier Badge Icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    currentAchievedTier.color.opacity(0.35),
                                    currentAchievedTier.color.opacity(0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 36
                            )
                        )
                        .frame(width: 64, height: 64)

                    Image(currentAchievedTier.assetImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(currentAchievedTier.color.opacity(0.7), lineWidth: 2)
                        )
                        .shadow(color: currentAchievedTier.color.opacity(0.35), radius: 8)
                }
                .metallicSheen(trigger: true, duration: 0.85, delay: 0.2)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(currentAchievedTier.displayName)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(currentAchievedTier.color)

                        Text(L10n.t("当前段位", "Current Tier"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Colors.emberDeep)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.ember, in: Capsule())
                    }

                    if let w = user1RM, w > 0 {
                        Text(L10n.t("最佳 1RM 纪录: \(formatKg(w)) \(unit)", "Best 1RM: \(formatKg(w)) \(unit)"))
                            .font(.system(size: 13.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    } else {
                        Text(L10n.t("尚未记录训练组，开练即解锁段位", "No logged sets yet — complete a session to rank"))
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }

                Spacer()
            }

            // Progress bar to next tier
            if let nextTarget = tierProgressData.nextTargetKg {
                let currentWeight = user1RM ?? 0
                let gap = max(0, nextTarget - currentWeight)
                let nextTier = StrengthTier(rawValue: currentAchievedTier.rawValue + 1) ?? .hundredFold

                VStack(spacing: 5) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.Colors.surfaceSunken)
                                .frame(height: 7)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.Colors.ember.opacity(0.8), Theme.Colors.ember],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, geo.size.width * CGFloat(tierProgressData.progress)), height: 7)
                        }
                    }
                    .frame(height: 7)

                    HStack {
                        Text(L10n.t("晋升 [\(nextTier.displayName)] 还需 +\(formatKg(gap)) \(unit)", "+\(formatKg(gap)) \(unit) to [\(nextTier.displayName)]"))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Theme.Colors.textMuted)

                        Spacer()

                        Text("\(Int(tierProgressData.progress * 100))%")
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.Colors.ember)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(Theme.Colors.surfaceSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .strokeBorder(Theme.Colors.borderMetal.opacity(0.7), lineWidth: Theme.Border.hairline)
        )
    }

    // MARK: - 2. Bodyweight Interactive Selector

    private var bodyweightPickerRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.t("参考体重 (影响标准对比)", "Reference Bodyweight"))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)

                Spacer()

                Text("\(Int(selectedBodyweight)) kg")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.Colors.ember)
            }

            // Quick weight chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([55.0, 65.0, 75.0, 85.0, 95.0, 105.0], id: \.self) { bw in
                        let isSelected = Int(selectedBodyweight) == Int(bw)
                        Button {
                            selectedBodyweight = bw
                            ForgeHaptics.selection()
                        } label: {
                            Text("\(Int(bw)) kg")
                                .font(.system(size: 12.5, weight: isSelected ? .bold : .medium, design: .monospaced))
                                .foregroundStyle(isSelected ? Theme.Colors.emberDeep : Theme.Colors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4.5)
                                .background(isSelected ? Theme.Colors.ember : Theme.Colors.surfaceSunken, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(isSelected ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - 3. 6-Tier Standards Ladder

    private var ladderTable: some View {
        VStack(spacing: 8) {
            ForEach(ladder.reversed(), id: \.tier) { row in
                ladderRow(row)
            }
        }
        .padding(.top, 4)
    }

    private func ladderRow(_ row: ExerciseLadderTier) -> some View {
        let isCurrent = currentAchievedTier == row.tier

        return HStack(spacing: 10) {
            // Small badge thumbnail
            Image(row.tier.assetImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(isCurrent ? Theme.Colors.ember : row.tier.color.opacity(0.4), lineWidth: isCurrent ? 1.5 : 0.5)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.tier.displayName)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(isCurrent ? Theme.Colors.ember : Theme.Colors.textPrimary)

                    if isCurrent {
                        Text(L10n.t("你的段位", "Your Tier"))
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(Theme.Colors.emberDeep)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Theme.Colors.ember, in: Capsule())
                    }
                }

                Text(row.label)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            // Range label
            Text(weightRangeText(row))
                .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                .foregroundStyle(isCurrent ? Theme.Colors.ember : Theme.Colors.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                .fill(isCurrent ? Theme.Colors.surfaceSunken : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                .strokeBorder(isCurrent ? Theme.Colors.ember.opacity(0.8) : Theme.Colors.borderHairline.opacity(0.5), lineWidth: isCurrent ? 1.2 : Theme.Border.hairline)
        )
    }

    private func weightRangeText(_ row: ExerciseLadderTier) -> String {
        if row.tier == .pigIron {
            if let max = row.maxWeightKg {
                return "< \(formatKg(max)) \(unit)"
            }
            return "0 \(unit)"
        } else if let max = row.maxWeightKg {
            return "\(formatKg(row.minWeightKg))–\(formatKg(max)) \(unit)"
        } else {
            return "≥ \(formatKg(row.minWeightKg)) \(unit)"
        }
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}
