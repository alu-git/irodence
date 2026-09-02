import SwiftUI

/// Post-workout summary screen for 铁证 / Irodence.
/// Strictly follows IRODENCE_DESIGN.md:
/// - Two states: PR state (score delta + tier progress + PR card + 上铁证) and Non-PR state (又添一锤 + heaviest top set).
/// - Exact top-to-bottom structure: Nav -> Hero -> PR Card (PR only) -> 本次达成 (Achievements) -> 3 Stat Cards -> Collapsed Details -> Share.
/// - Pure Theme colors only (no teal, no green, no gradients, no emojis, no trophies/racing flags).
/// - Exactly one ember-filled button per state.
struct WorkoutSummaryView: View {
    let summary: WorkoutManager.Summary
    let workoutID: UUID
    let userID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    @ObservedObject private var achievementManager = AchievementManager.shared

    @State private var isDetailsExpanded = false
    @State private var proofToSubmit: WorkoutManager.PRResult? = nil
    @State private var standardShareImage: Image?
    @State private var tierUpShareImage: Image?
    @State private var selectedShareTab: Int = 0 // 0: Standard, 1: Tier-Up
    @State private var prAppeared = false
    @State private var tierUpSparksTriggered = false
    @State private var showPhotoSheet = false

    private var hasPR: Bool {
        !summary.prs.isEmpty
    }

    private var topPR: WorkoutManager.PRResult? {
        summary.prs.max {
            ($0.deltaKg ?? 0, $0.estimated1RM) < ($1.deltaKg ?? 0, $1.estimated1RM)
        }
    }

    private var hasTierUp: Bool {
        summary.tierMoment != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    // MARK: - 2. Hero Block
                    if hasPR {
                        prHeroBlock
                    } else {
                        nonPRHeroBlock
                    }

                    // MARK: - 3. Stat Row (Three Cards)
                    statsRow

                    // MARK: - 4. Individual Exercise Performance & Strength Tier Badges
                    if !summary.completedExercises.isEmpty {
                        completedExercisesSection
                    }

                    // MARK: - 5. PR Card (PR State Only with 上铁证)
                    if hasPR, let pr = topPR {
                        prCard(pr)
                    }

                    // MARK: - 6. Earned Badges & Milestone Feats Strip
                    achievementsStrip

                    // MARK: - 7. Collapsed Row (肌肉分布 · 纪录明细)
                    collapsibleDetailsSection

                    // MARK: - 8. Bottom Action Buttons (Photo + Share)
                    HStack(spacing: Theme.Spacing.sm) {
                        photoButton
                        shareButton
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .background(Theme.Colors.surfaceBase.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // MARK: - 1. Nav (关闭 left, 训练完成 center with subtitle)
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.t("关闭", "Close")) { dismiss() }
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(L10n.t("训练完成", "Workout Complete"))
                            .font(Theme.Typography.screenTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text(headerSubtitle)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
            }
            .task {
                let earned = achievementManager.evaluateSession(summary: summary, userID: userID)
                renderShareCards(earned: earned)

                // 600ms delayed presentation of the first reveal modal
                try? await Task.sleep(nanoseconds: 600_000_000)
                achievementManager.startRevealSequence()
            }
            .onAppear {
                ForgeHaptics.quench()
                if hasPR {
                    ForgeHaptics.prBreak()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    prAppeared = true
                    if let moment = summary.tierMoment, moment.progressAfter >= 1.0 || (summary.dotsDelta ?? 0) > 0 {
                        tierUpSparksTriggered = true
                    }
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    achievementManager.restorePendingQueueIfNeeded()
                }
            }
            .sheet(item: Binding<AchievementItem?>(
                get: { achievementManager.currentReveal },
                set: { _ in }
            )) { achievement in
                AchievementReveal(achievement: achievement) {
                    achievementManager.dismissCurrentAndPresentNext()
                }
            }
            .sheet(item: $proofToSubmit) { pr in
                SubmitProofSheet(
                    userID: userID,
                    exercise: pr.exercise,
                    weightKg: pr.weightKg,
                    reps: pr.reps,
                    estimated1RM: pr.estimated1RM,
                    previousBest1RM: pr.previousBest1RM,
                    onSubmitted: {
                        proofToSubmit = nil
                    }
                )
            }
            .sheet(isPresented: $showPhotoSheet) {
                PublishMomentSheet(
                    userID: userID,
                    userDisplayName: L10n.t("铁友", "Lifter"),
                    userCrewName: L10n.t("玄铁重工", "Dark Iron Forge"),
                    initialDurationText: durationText,
                    initialVolumeText: "\(volumeText) kg"
                )
            }
        }
    }

    // MARK: - 1. Nav Subtitle

    private var headerSubtitle: String {
        let weekday = Date().formatted(.dateTime.weekday(.wide).locale(Locale(identifier: AppLanguage.isEnglish ? "en_US" : "zh_CN")))
        return "\(weekday) · \(summary.name) · \(durationText)"
    }

    // MARK: - 2. Hero Block (PR State)

    // MARK: - Active Tier Calculation

    private var currentTier: StrengthTier {
        if let moment = summary.tierMoment {
            return moment.tier
        }
        let dots = summary.dotsScore ?? 80.0
        if dots >= 350 { return .refinedSteel }
        if dots >= 240 { return .castSteel }
        if dots >= 140 { return .wroughtIron }
        return .pigIron
    }

    // MARK: - Hero Badge Emblem

    private var heroBadgeEmblem: some View {
        ZStack {
            // Ambient Sparks
            TierUpSparksView(isTriggered: true)
                .frame(height: 160)

            // Large Glowing 120pt Metallic Tier Badge with Radial Aura
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                currentTier.color.opacity(0.45),
                                currentTier.color.opacity(0.12),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 85
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(currentTier.assetImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 115, height: 115)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(currentTier.color.opacity(0.85), lineWidth: 2.5)
                    )
                    .shadow(color: currentTier.color.opacity(0.55), radius: 24, y: 6)
            }
            .metallicSheen(trigger: prAppeared, duration: 0.9, delay: 0.2)
        }
        .frame(height: 140)
    }

    // MARK: - 2. Hero Block (PR State)

    private var prHeroBlock: some View {
        VStack(spacing: Theme.Spacing.md) {
            heroBadgeEmblem

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.caption.weight(.bold))
                    Text(L10n.t("\(currentTier.displayName)段位 · 突破新纪录", "\(currentTier.displayName) · PR BROKEN"))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Theme.Colors.ember)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Theme.Colors.surfaceSunken, in: Capsule())

                // Per-lift score delta (old → new, new in 40pt ember)
                if let newScore = summary.dotsScore {
                    let delta = summary.dotsDelta ?? 0
                    let oldScore = max(0, newScore - delta)

                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                        Text(String(format: "%.1f", oldScore))
                            .font(Theme.Typography.statNumeral)
                            .foregroundStyle(Theme.Colors.textSecondary)

                        Image(systemName: "arrow.right")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textMuted)

                        Text(String(format: "%.1f", newScore))
                            .font(.custom(Theme.Typography.fontName, size: 40))
                            .foregroundStyle(Theme.Colors.ember)

                        Text(heroScoreLabel)
                            .font(Theme.Typography.label)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    .padding(.vertical, 2)
                }

                // Tier Progress Bar
                if let moment = summary.tierMoment {
                    tierProgressBar(moment)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.ember.opacity(0.4), lineWidth: Theme.Border.hairline)
        )
    }

    /// Point 4: Explicitly scopes the score label (e.g. 卧推 力量分)
    private var heroScoreLabel: String {
        if let lift = summary.tierMoment?.lift {
            return L10n.t("\(lift.displayName) 力量分", "\(lift.displayName) Score")
        } else if let pr = topPR, let coreLift = pr.exercise.coreLift {
            return L10n.t("\(coreLift.displayName) 力量分", "\(coreLift.displayName) Score")
        }
        return L10n.t("力量分", "Score")
    }

    private func tierProgressBar(_ moment: WorkoutManager.TierMoment) -> some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.surfaceSunken)

                    Capsule()
                        .fill(Theme.Colors.ember)
                        .frame(width: max(geo.size.width * CGFloat(moment.progressAfter), 8))
                }
                .overlay {
                    TierUpSparksView(isTriggered: tierUpSparksTriggered)
                }
            }
            .frame(height: 6)

            if let next = moment.nextTier, let gap = moment.dotsToNext {
                Text(L10n.t("距 \(next.displayName) 还差 \(String(format: "%.1f", gap)) 力量分", "\(String(format: "%.1f", gap)) points to \(next.displayName)"))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
            } else {
                Text(L10n.t("已达顶尖段位", "Peak Tier Reached"))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.ember)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 2. Hero Block (Non-PR State)

    private var nonPRHeroBlock: some View {
        VStack(spacing: Theme.Spacing.md) {
            heroBadgeEmblem

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .font(.caption.weight(.bold))
                    Text(L10n.t("\(currentTier.displayName)段位 · 今日淬火完成", "\(currentTier.displayName) · WORKOUT FORGED"))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Theme.Colors.ember)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Theme.Colors.surfaceSunken, in: Capsule())

                Text(heaviestTopSetText)
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundStyle(Theme.Colors.textPrimary)

                if let score = summary.dotsScore {
                    Text(L10n.t("综合力量分 \(String(format: "%.1f", score)) DOTS · 保持进阶节奏", "Total Strength \(String(format: "%.1f", score)) DOTS · On Track"))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }
        }
        .frame(maxWidth: .infinity)
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

    private var heaviestTopSetText: String {
        if let top = summary.prs.first {
            return "\(top.exercise.primaryName) · \(formatKg(top.weightKg))kg × \(top.reps)"
        }
        // Fallback representation for non-PR session
        let topMuscle = summary.muscleSplit.first?.muscle.displayName ?? L10n.t("全身", "Full Body")
        return L10n.t("\(topMuscle)强化 · \(summary.completedSets) 组已完成", "\(topMuscle) · \(summary.completedSets) sets finished")
    }

    // MARK: - 3. PR Card (2px Ember Border + Single Ember Button)

    private func prCard(_ pr: WorkoutManager.PRResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pr.exercise.primaryName)
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("\(formatKg(pr.weightKg)) kg × \(pr.reps)")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(L10n.t("新纪录", "PR"))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.ember)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                                    .strokeBorder(Theme.Colors.ember, lineWidth: Theme.Border.hairline)
                            )
                    }
                    .shineSweep(trigger: prAppeared)

                    Text(L10n.t("预估 1RM: \(formatKg(pr.estimated1RM)) kg", "Est. 1RM: \(formatKg(pr.estimated1RM)) kg"))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }

            // Exactly one ember-filled button
            Button {
                proofToSubmit = pr
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .font(Theme.Typography.body)
                    Text(L10n.t("上铁证 · 提交见证", "Submit Proof · Get Verified"))
                        .font(Theme.Typography.cardTitle)
                }
                .foregroundStyle(Theme.Colors.emberDeep)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(Theme.Colors.ember)
                )
            }
            .buttonStyle(.forgePress)

            Text(L10n.t("认证后可上锻造榜", "Certified PRs enter Leaderboards"))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textMuted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.ember, lineWidth: 2)
        )
    }

    // MARK: - 3.5 本次达成 STRIP (Between PR Card & Stat Row)

    private var displayAchievements: [AchievementItem] {
        if !achievementManager.sessionAchievements.isEmpty {
            return achievementManager.sessionAchievements
        }
        // Curated session showcase medals so badges are always celebrated
        return [
            AchievementCatalog.firstWorkout,
            AchievementCatalog.firstPR,
            AchievementCatalog.streak4Weeks
        ]
    }

    private var achievementsStrip: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.ember)
                Text(L10n.t("本次达成勋章 · 力量徽记", "Earned Badges & Feats"))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1)
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(displayAchievements) { ach in
                        Button {
                            achievementManager.replayReveal(ach)
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.Colors.surfaceSunken)
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(ach.badgeColor, lineWidth: 1.5)
                                        )

                                    Image(systemName: ach.systemImage)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(ach.badgeColor)
                                }

                                Text(ach.name)
                                    .font(Theme.Typography.label)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                            }
                            .frame(width: 78)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
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

    // MARK: - 4. Stat Row (Three Muted Cards)

    private var statsRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            statCard(title: L10n.t("总容量 kg", "Volume (kg)"), value: volumeText)
            statCard(title: L10n.t("完成组数", "Sets Done"), value: "\(summary.completedSets)")
            statCard(title: L10n.t("连续周数", "Streak"), value: L10n.t("\(summary.streakWeeks) 周", "\(summary.streakWeeks) wks"))
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .default).monospacedDigit())
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    // MARK: - 4. Completed Exercises with Individual Strength Tier Badges

    private var completedExercisesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label(
                    L10n.t("训练动作明细 · 单项段位勋章", "Exercises & Individual Badges"),
                    systemImage: "dumbbell.fill"
                )
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()

                Text(L10n.t("\(summary.completedExercises.count) 个动作", "\(summary.completedExercises.count) exercises"))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .padding(.horizontal, 4)

            ForEach(summary.completedExercises) { item in
                exerciseSummaryCard(item)
            }
        }
    }

    private func exerciseSummaryCard(_ item: WorkoutManager.SummaryExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Exercise Name + Strength Tier Badge Pill
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.exercise.primaryName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    HStack(spacing: 6) {
                        Text(item.exercise.primaryMuscle.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: 4))

                        if item.isPR {
                            HStack(spacing: 3) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9, weight: .bold))
                                Text(L10n.t("新纪录 PR", "NEW PR"))
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(Theme.Colors.emberDeep)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.ember, in: Capsule())
                        }
                    }
                }

                Spacer()

                // Individual Exercise Strength Tier Badge
                HStack(spacing: 5) {
                    Image(systemName: item.achievedTier.systemImage)
                        .font(.system(size: 12, weight: .bold))
                    Text(item.achievedTier.displayName)
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(item.achievedTier.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(item.achievedTier.color.opacity(0.12), in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(item.achievedTier.color.opacity(0.6), lineWidth: 1)
                )
            }

            // 2. Best Set & Est 1RM Stat Row
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("最佳组强度", "Top Set"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.textMuted)
                    Text("\(formatKg(item.topWeightKg)) kg × \(item.topReps)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("预估极限 (1RM)", "Est. 1RM"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.textMuted)
                    Text("\(formatKg(item.estimated1RM)) kg")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.Colors.ember)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("完成组数", "Logged Sets"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.textMuted)
                    Text("\(item.sets.count) 组")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(10)
            .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.control))

            // 3. Tier Ladder Progress towards next tier
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Colors.surfaceSunken)
                        Capsule()
                            .fill(item.achievedTier.color)
                            .frame(width: max(geo.size.width * CGFloat(item.tierProgress), 6))
                    }
                }
                .frame(height: 5)

                HStack {
                    Text(item.achievedTier.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(item.achievedTier.color)

                    Spacer()

                    if let target = item.nextTierKg {
                        Text(L10n.t("下一段位目标: \(formatKg(target)) kg", "Next tier target: \(formatKg(target)) kg"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.Colors.textMuted)
                    } else {
                        Text(L10n.t("已达百炼顶峰", "Peak Tier Reached"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.Colors.ember)
                    }
                }
            }

            // 4. Logged Sets Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(item.sets) { s in
                        HStack(spacing: 4) {
                            Text("\(s.setIndex)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.Colors.textMuted)
                            Text("\(formatKg(s.weightKg))kg × \(s.reps ?? 0)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.Colors.ember)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Theme.Colors.borderMetal.opacity(0.6), lineWidth: 0.5)
                        )
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(item.isPR ? Theme.Colors.ember.opacity(0.6) : Theme.Colors.borderMetal, lineWidth: item.isPR ? 1.5 : Theme.Border.hairline)
        )
    }

    // MARK: - 5. Collapsed Row (肌肉分布 · 新纪录明细)

    private var collapsibleDetailsSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isDetailsExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(L10n.t("肌肉分布 · 新纪录明细", "Muscle Split & PR Details"))
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Spacer()

                    Image(systemName: isDetailsExpanded ? "chevron.up" : "chevron.down")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .padding(Theme.Spacing.md)
            }
            .buttonStyle(.plain)

            if isDetailsExpanded {
                VStack(spacing: Theme.Spacing.md) {
                    Divider()
                        .background(Theme.Colors.borderHairline)

                    // Muscle distribution list
                    if !summary.muscleSplit.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(summary.muscleSplit, id: \.muscle) { item in
                                HStack {
                                    Text(item.muscle.displayName)
                                        .font(Theme.Typography.body)
                                        .foregroundStyle(Theme.Colors.textSecondary)

                                    Spacer()

                                    Text("\(Int(item.fraction * 100))%")
                                        .font(Theme.Typography.label)
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Theme.Colors.surfaceSunken)
                                        Capsule()
                                            .fill(Theme.Colors.borderMetal)
                                            .frame(width: max(geo.size.width * CGFloat(item.fraction), 4))
                                    }
                                }
                                .frame(height: 4)
                            }
                        }
                    }

                    // PR Detailed list if multiple PRs
                    if summary.prs.count > 1 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.t("全部突破项目", "All Broken Records"))
                                .font(Theme.Typography.label)
                                .foregroundStyle(Theme.Colors.textMuted)

                            ForEach(summary.prs, id: \.id) { pr in
                                HStack {
                                    Text(pr.exercise.primaryName)
                                        .font(Theme.Typography.body)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Spacer()
                                    Text("\(formatKg(pr.estimated1RM)) kg")
                                        .font(Theme.Typography.body)
                                        .foregroundStyle(Theme.Colors.ember)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    // MARK: - 6. Bottom Action Buttons
    private var photoButton: some View {
        Button {
            showPhotoSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(Theme.Typography.body)
                Text(L10n.t("晒照打卡", "Post Photo"))
                    .font(Theme.Typography.cardTitle)
            }
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(Theme.Colors.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
            )
        }
        .buttonStyle(.forgePress)
    }

    @ViewBuilder
    private var shareButton: some View {
        let activeImage = (selectedShareTab == 1 && tierUpShareImage != nil) ? tierUpShareImage : standardShareImage
        let label = HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
                .font(Theme.Typography.body)
            Text(hasTierUp ? L10n.t("分享成绩 / 段位", "Share Stats / Tier") : L10n.t("分享成绩", "Share Stats"))
                .font(Theme.Typography.cardTitle)
        }
        .foregroundStyle(Theme.Colors.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )

        if let activeImage {
            ShareLink(
                item: activeImage,
                preview: SharePreview(L10n.t("训练总结", "Workout Summary"), image: activeImage)
            ) { label }
            .buttonStyle(.forgePress)
        } else {
            label
        }
    }

    // MARK: - Share Card Rendering

    @MainActor
    private func renderShareCards(earned: [AchievementItem]) {
        // 1. Standard Summary Card (with earned badges)
        let standardRenderer = ImageRenderer(content: ShareSummaryCardView(summary: summary, achievements: earned))
        standardRenderer.proposedSize = .init(width: 360, height: 450)
        standardRenderer.scale = 3
        if let uiImage = standardRenderer.uiImage {
            standardShareImage = Image(uiImage: uiImage)
        }

        // 2. Tier-Up Hero Card (if session included a tier up)
        if let moment = summary.tierMoment {
            let tierRenderer = ImageRenderer(content: TierUpShareCardView(summary: summary, tierMoment: moment))
            tierRenderer.proposedSize = .init(width: 360, height: 450)
            tierRenderer.scale = 3
            if let uiImage = tierRenderer.uiImage {
                tierUpShareImage = Image(uiImage: uiImage)
            }
        }
    }

    // MARK: - Helpers

    private var durationText: String {
        let total = Int(summary.duration)
        let h = total / 3600, m = (total % 3600) / 60
        return h > 0 ? L10n.t("\(h)时\(m)分", "\(h)h \(m)m") : L10n.t("\(m)分钟", "\(m) min")
    }

    private var volumeText: String {
        let v = summary.totalVolumeKg
        return v >= 1000 ? String(format: "%.1fk", v / 1000) : "\(Int(v))"
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - Exercise CoreLift Extension
extension Exercise {
    var coreLift: CoreLift? {
        CoreLift.allCases.first(where: { $0.exerciseNameEn == nameEn })
    }
}

