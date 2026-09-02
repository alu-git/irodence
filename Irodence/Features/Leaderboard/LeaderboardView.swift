import SwiftUI

/// Scope selection: 同炉 (default) | {体重}kg级 | 全球
enum LeaderboardScope: Hashable {
    case crew
    case weightClass(Int)
    case global

    func title(userWeightClass: Int) -> String {
        switch self {
        case .crew:
            return L10n.t("同炉", "Crew")
        case .weightClass(let kg):
            let weight = kg > 0 ? kg : userWeightClass
            return L10n.t("\(weight)kg级", "\(weight)kg Class")
        case .global:
            return L10n.t("全球", "Global")
        }
    }
}

/// Cached rank information for the current user to avoid repeated list scans.
struct SelfRankInfo {
    var rank: Int?
    var tier: StrengthTier?
    var relativeStrengthText: String?
    var scoreText: String?
    var scoreGapText: String?
    var isCertified: Bool

    init(
        rank: Int? = nil,
        tier: StrengthTier? = nil,
        relativeStrengthText: String? = nil,
        scoreText: String? = nil,
        scoreGapText: String? = nil,
        isCertified: Bool = false
    ) {
        self.rank = rank
        self.tier = tier
        self.relativeStrengthText = relativeStrengthText
        self.scoreText = scoreText
        self.scoreGapText = scoreGapText
        self.isCertified = isCertified
    }
}

/// 锻造榜主视图 (LeaderboardView)
/// Specified in IRODENCE_DESIGN.md.
struct LeaderboardView: View {
    @ObservedObject var service: SocialService
    @StateObject private var library: ExerciseService
    @StateObject private var profileService: ProfileService
    @StateObject private var crewService = CrewService()

    @State private var selectedScope: LeaderboardScope = .crew
    @State private var selectedTarget: LeaderboardTarget = .core(.squat)
    @State private var customSelectedExercise: Exercise? = nil
    @State private var showExercisePicker = false
    @State private var showCertificationSheet = false
    @State private var showLeaderboardInfo = false
    @State private var selectedExerciseForCertification: Exercise?
    @State private var onlyCertified = false

    // Performance-optimized state cache
    @State private var processedEntries: [LeaderboardEntryItem] = []
    @State private var selfRankInfo = SelfRankInfo()

    #if DEBUG
    @State private var useMockDataIfEmpty = true
    #endif

    init(service: SocialService, library: ExerciseService? = nil) {
        self.service = service
        _library = StateObject(wrappedValue: library ?? ExerciseService())
        _profileService = StateObject(wrappedValue: ProfileService(userID: service.userID))
    }

    private var currentWeightClass: Int {
        let profile = profileService.profile
        return WeightClassHelper.weightClass(for: profile?.bodyweightKg, sex: profile?.sex)
    }

    private var availableScopes: [LeaderboardScope] {
        [.crew, .weightClass(currentWeightClass), .global]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Colors.surfaceBase
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection

                Divider()
                    .background(Theme.Colors.borderHairline)

                chipRowAndSortHeader

                Divider()
                    .background(Theme.Colors.borderHairline)

                contentList
                    .padding(.bottom, 88) // Space for pinned self row
            }

            pinnedSelfRow
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
        }
        .navigationTitle(L10n.t("锻造榜", "Leaderboard"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showLeaderboardInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .task {
            await reloadData()
        }
        .onChange(of: selectedTarget) { _ in
            updateProcessedEntries()
            Task { await reloadData() }
        }
        .onChange(of: selectedScope) { _ in
            updateProcessedEntries()
            Task { await reloadData() }
        }
        .onChange(of: service.entries) { _ in
            updateProcessedEntries()
        }
        .refreshable {
            await reloadData()
        }
        .sheet(isPresented: $showLeaderboardInfo) {
            LeaderboardInfoSheet()
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerSheet(library: library) { exercise in
                customSelectedExercise = exercise
                selectedTarget = .custom(exercise)
            }
        }
        .sheet(isPresented: $showCertificationSheet) {
            if let exercise = selectedExerciseForCertification ?? defaultExerciseForCurrentTarget {
                SubmitProofSheet(
                    userID: service.userID,
                    exercise: exercise,
                    weightKg: 100.0,
                    reps: 1,
                    estimated1RM: 100.0,
                    previousBest1RM: nil,
                    onSubmitted: {
                        showCertificationSheet = false
                        Task { await reloadData() }
                    }
                )
            }
        }
    }

    // MARK: - Header & Scope Pills

    private var headerSection: some View {
        HStack(spacing: 8) {
            ForEach(availableScopes, id: \.self) { scope in
                let isSelected = scopeMatches(scope, selectedScope)
                Button {
                    selectedScope = scope
                } label: {
                    Text(scope.title(userWeightClass: currentWeightClass))
                        .font(Theme.Typography.label)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.pill)
                                .fill(isSelected ? Theme.Colors.ember : Theme.Colors.surfaceRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.pill)
                                .strokeBorder(isSelected ? Color.clear : Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                        .foregroundStyle(isSelected ? Theme.Colors.emberDeep : Theme.Colors.textSecondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.surfaceBase)
    }

    private func scopeMatches(_ lhs: LeaderboardScope, _ rhs: LeaderboardScope) -> Bool {
        switch (lhs, rhs) {
        case (.crew, .crew): return true
        case (.global, .global): return true
        case (.weightClass, .weightClass): return true
        default: return false
        }
    }

    // MARK: - Chip Row & Sort Indicator

    private var chipRowAndSortHeader: some View {
        VStack(spacing: 0) {
            // Row 1: Dedicated Horizontal Tabs with generous spacing
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.lg) {
                    // 1. 深蹲
                    chipButton(target: .core(.squat))
                    // 2. 卧推
                    chipButton(target: .core(.bench))
                    // 3. 硬拉
                    chipButton(target: .core(.deadlift))
                    // 4. 总和
                    chipButton(target: .total)

                    // 5. Fifth selected custom exercise (if selected)
                    if let custom = customSelectedExercise {
                        chipButton(target: .custom(custom))
                    }

                    // 6. 更多 Button
                    Button {
                        showExercisePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(L10n.t("更多", "More"))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 40)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
            .padding(.top, Theme.Spacing.xs)

            // Row 2: Clean Subheader / Filter & Sort Bar
            HStack(spacing: 8) {
                Menu {
                    Button {
                        onlyCertified = false
                        updateProcessedEntries()
                        ForgeHaptics.selection()
                    } label: {
                        Label(L10n.t("全员总榜 (包含自测打卡)", "All Lifters (Inc. Self-Reported)"), systemImage: "list.bullet")
                    }

                    Button {
                        onlyCertified = true
                        updateProcessedEntries()
                        ForgeHaptics.selection()
                    } label: {
                        Label(L10n.t("铁证认证榜 (仅限视频验杠)", "Certified Proofs Only (Video)"), systemImage: "checkmark.seal.fill")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: onlyCertified ? "checkmark.seal.fill" : "list.bullet")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(onlyCertified ? Theme.Colors.ember : Theme.Colors.textSecondary)
                        Text(onlyCertified ? L10n.t("铁证认证榜", "Certified Only") : L10n.t("全员总榜 (含自测)", "All (Inc. Self-Reported)"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(onlyCertified ? Theme.Colors.ember : Theme.Colors.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.surfaceRaised, in: Capsule())
                    .overlay(Capsule().strokeBorder(onlyCertified ? Theme.Colors.ember.opacity(0.4) : Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline))
                }
                .buttonStyle(.platePillPress)

                Spacer()

                Text(selectedTarget.isCore ? L10n.t("力量分 ↓", "Score ↓") : L10n.t("1RM ↓", "1RM ↓"))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.xs / 2)
            .background(Theme.Colors.surfaceBase)
        }
    }

    private func chipButton(target: LeaderboardTarget) -> some View {
        let isSelected = selectedTarget.id == target.id
        return Button {
            selectedTarget = target
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Text(target.displayName)
                    .font(Theme.Typography.cardTitle)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                Rectangle()
                    .fill(isSelected ? Theme.Colors.textPrimary : Color.clear)
                    .frame(height: 2)
            }
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content List

    private var contentList: some View {
        Group {
            if service.isLoading && processedEntries.isEmpty {
                GymLoadingView(L10n.t("正在锻打…", "Forging ranks…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if processedEntries.count < 3 {
                // Sparse boards (<3 certified entries) render the empty state
                LeaderboardEmptyStateView(
                    message: L10n.t("虚位以待，上铁证成为首个上榜者", "Spot open — Submit proof to be first on the board"),
                    onCertifyTapped: {
                        prepareCertification()
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.xs) {
                        ForEach(Array(processedEntries.enumerated()), id: \.element.id) { index, entry in
                            LeaderboardRowView(
                                rank: index + 1,
                                entry: entry,
                                isCore: selectedTarget.isCore,
                                isSelf: entry.userID == service.userID
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)
                }
            }
        }
    }

    // MARK: - Pinned Self Row

    private var pinnedSelfRow: some View {
        LeaderboardPinnedSelfRow(
            target: selectedTarget,
            userRank: selfRankInfo.rank,
            tier: selfRankInfo.tier,
            relativeStrengthText: selfRankInfo.relativeStrengthText,
            scoreText: selfRankInfo.scoreText,
            scoreGapText: selfRankInfo.scoreGapText,
            isCertified: selfRankInfo.isCertified,
            onCertifyTapped: {
                prepareCertification()
            }
        )
    }

    // MARK: - Optimized Data Processing

    private func updateProcessedEntries() {
        var items: [LeaderboardEntryItem] = []

        #if DEBUG
        if useMockDataIfEmpty && service.entries.isEmpty {
            items = MockLeaderboardData.users.filter { $0.targetID == selectedTarget.id && $0.isCertified }

            switch selectedScope {
            case .crew:
                let userCrewID = crewService.currentCrew?.id ?? MockLeaderboardData.mockCrewID
                items = items.filter { $0.crewID == userCrewID }
            case .weightClass(let kg):
                let targetKg = kg > 0 ? kg : currentWeightClass
                items = items.filter { WeightClassHelper.weightClass(for: $0.bodyweightKg, sex: $0.sex) == targetKg }
            case .global:
                break
            }

            if selectedTarget.isCore {
                items.sort { ($0.dotsScore ?? 0) > ($1.dotsScore ?? 0) }
            } else {
                // Non-core: ranked by estimated 1RM within same sex and weight class
                items.sort { $0.estimated1RM > $1.estimated1RM }
            }

            // Sparse board threshold: < 3 entries suppressed
            if items.count < 3 {
                self.processedEntries = []
            } else {
                self.processedEntries = items
            }
            self.updateSelfRankInfo(from: items)
            return
        }
        #endif

        let liveItems = service.entries.compactMap { entry -> LeaderboardEntryItem? in
            guard let sex = entry.sex,
                  let bw = entry.bodyweightKg else { return nil }

            let dots: Double? = selectedTarget.isCore ? entry.dotsScore : nil
            let tier: StrengthTier? = selectedTarget.isCore ? entry.tier : nil

            return LeaderboardEntryItem(
                id: entry.id,
                userID: entry.userID,
                displayName: entry.displayName,
                avatarURL: entry.avatarURL,
                sex: sex,
                bodyweightKg: bw,
                targetID: selectedTarget.id,
                weightKg: entry.weightKg,
                estimated1RM: entry.estimated1RM,
                reps: entry.reps,
                dotsScore: dots,
                tier: tier,
                isCertified: true,
                crewID: nil
            )
        }

        items = liveItems

        switch selectedScope {
        case .crew:
            if let _ = crewService.currentCrew {
                let memberIDs = Set(crewService.members.map(\.userID))
                items = items.filter { memberIDs.contains($0.userID) }
            }
        case .weightClass(let kg):
            let targetKg = kg > 0 ? kg : currentWeightClass
            items = items.filter { WeightClassHelper.weightClass(for: $0.bodyweightKg, sex: $0.sex) == targetKg }
        case .global:
            break
        }

        if onlyCertified {
            items = items.filter(\.isCertified)
        }

        if selectedTarget.isCore {
            items.sort { ($0.dotsScore ?? 0) > ($1.dotsScore ?? 0) }
        } else {
            items.sort { $0.estimated1RM > $1.estimated1RM }
        }

        // Query layer threshold enforcement
        if items.count < 3 {
            self.processedEntries = []
        } else {
            self.processedEntries = items
        }
        self.updateSelfRankInfo(from: items)
    }

    private func updateSelfRankInfo(from items: [LeaderboardEntryItem]) {
        guard let index = items.firstIndex(where: { $0.userID == service.userID }) else {
            self.selfRankInfo = SelfRankInfo(
                rank: nil,
                tier: nil,
                relativeStrengthText: nil,
                scoreText: nil,
                scoreGapText: nil,
                isCertified: false
            )
            return
        }

        let rank = index + 1
        let userEntry = items[index]

        let scoreText: String = {
            if selectedTarget.isCore {
                return userEntry.dotsScore.map { String(format: "%.0f", $0) } ?? "—"
            } else {
                return "\(formatKg(userEntry.estimated1RM))kg"
            }
        }()

        let scoreGapText: String? = {
            guard rank > 1 else { return L10n.t("榜首", "#1 Leader") }
            if selectedTarget.isCore {
                guard let prevScore = items[rank - 2].dotsScore, let currentScore = userEntry.dotsScore else { return nil }
                let gap = max(0, prevScore - currentScore)
                return L10n.t("距上一名 \(String(format: "%.0f", gap))分", "\(String(format: "%.0f", gap)) pts behind #\(rank - 1)")
            } else {
                let prev1RM = items[rank - 2].estimated1RM
                let gap = max(0, prev1RM - userEntry.estimated1RM)
                return L10n.t("距上一名 \(formatKg(gap))kg", "\(formatKg(gap))kg behind #\(rank - 1)")
            }
        }()

        self.selfRankInfo = SelfRankInfo(
            rank: rank,
            tier: userEntry.tier,
            relativeStrengthText: userEntry.relativeStrengthText,
            scoreText: scoreText,
            scoreGapText: scoreGapText,
            isCertified: true
        )
    }

    private var defaultExerciseForCurrentTarget: Exercise? {
        switch selectedTarget {
        case .core(let coreLift):
            return library.exercises.first(where: { $0.nameEn == coreLift.exerciseNameEn })
        case .total:
            return library.exercises.first(where: { $0.nameEn == CoreLift.squat.exerciseNameEn })
        case .custom(let ex):
            return ex
        }
    }

    private func prepareCertification() {
        selectedExerciseForCertification = defaultExerciseForCurrentTarget
        showCertificationSheet = true
    }

    private func reloadData() async {
        await library.loadIfNeeded()
        await profileService.load(library: library)
        await crewService.loadUserCrew(userID: service.userID)

        if let exercise = defaultExerciseForCurrentTarget {
            await service.loadLeaderboard(exerciseID: exercise.id, minThreshold: 3)
        }

        updateProcessedEntries()
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

// MARK: - Compatibility Typealias
typealias LeaderboardBoardsView = LeaderboardView

// MARK: - Ranked Row View

struct LeaderboardRowView: View {
    let rank: Int
    let entry: LeaderboardEntryItem
    let isCore: Bool
    let isSelf: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Rank numeral (ember for #1 only)
            Text("\(rank)")
                .font(Theme.Typography.statNumeralSmall)
                .foregroundStyle(rank == 1 ? Theme.Colors.ember : Theme.Colors.textMuted)
                .frame(width: 28, alignment: .leading)

            // Avatar
            avatarView

            // Username + Team + 已认证 stamp pill
            VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(entry.displayName)
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    // Team / Crew Badge
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8.5))
                        Text(crewNameFor(entry.displayName))
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Colors.ember)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Theme.Colors.ember.opacity(0.12), in: Capsule())

                    if entry.isCertified {
                        certifiedStampPill
                    } else {
                        selfReportedStampPill
                    }
                }

                // Subtitle:
                // Core: {tier} · {weight}kg @ {bodyweight}kg
                // Non-core: {relativeStrength} · {weight}kg @ {bodyweight}kg
                Text(subtitleText)
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            // 力量分 (for core) or 1RM (for non-core) in 18pt medium
            Text(scoreText)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(isSelf ? Theme.Colors.ember : Theme.Colors.borderHairline, lineWidth: Theme.Border.hairline)
        )
    }

    private var subtitleText: String {
        if isCore, let tier = entry.tier {
            return "\(tier.displayName) · \(formatKg(entry.weightKg))kg @ \(formatKg(entry.bodyweightKg))kg"
        } else {
            return "\(entry.relativeStrengthText) · \(formatKg(entry.weightKg))kg @ \(formatKg(entry.bodyweightKg))kg"
        }
    }

    private var scoreText: String {
        if isCore {
            return entry.dotsScore.map { String(format: "%.0f", $0) } ?? "—"
        } else {
            return "\(formatKg(entry.estimated1RM))kg"
        }
    }

    private var avatarView: some View {
        Group {
            if let avatarURL = entry.avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    defaultAvatar
                }
            } else {
                defaultAvatar
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline))
    }

    private var defaultAvatar: some View {
        Circle()
            .fill(Theme.Colors.surfaceSunken)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Colors.textMuted)
            )
    }

    private var certifiedStampPill: some View {
        Text(L10n.t("已认证", "Certified"))
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Theme.Colors.ember)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                    .strokeBorder(Theme.Colors.ember.opacity(0.8), lineWidth: Theme.Border.hairline)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                            .fill(Theme.Colors.ember.opacity(0.12))
                    )
            )
    }

    private var selfReportedStampPill: some View {
        Text(L10n.t("自测", "Self-Log"))
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                    .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                            .fill(Theme.Colors.surfaceSunken)
                    )
            )
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    private func crewNameFor(_ name: String) -> String {
        if name.contains("麦昆") {
            return L10n.t("闪电车队", "Lightning")
        } else if name.contains("水手") {
            return L10n.t("大力菠菜营", "Popeye")
        } else if name.contains("老王") || name.contains("腿王") {
            return L10n.t("钢铁之翼", "Steel Wing")
        } else {
            return L10n.t("玄铁重工", "Dark Iron")
        }
    }
}

// MARK: - Pinned Bottom Self Row

struct LeaderboardPinnedSelfRow: View {
    let target: LeaderboardTarget
    let userRank: Int?
    let tier: StrengthTier?
    let relativeStrengthText: String?
    let scoreText: String?
    let scoreGapText: String?
    let isCertified: Bool
    let onCertifyTapped: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            if isCertified, let rank = userRank {
                // Certified user state
                Text("#\(rank)")
                    .font(Theme.Typography.statNumeralSmall)
                    .foregroundStyle(rank == 1 ? Theme.Colors.ember : Theme.Colors.textPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    if target.isCore, let tier = tier {
                        Text(L10n.t("你 · \(tier.displayName)", "You · \(tier.displayName)"))
                            .font(Theme.Typography.cardTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    } else if let rel = relativeStrengthText {
                        Text(L10n.t("你 · \(rel)", "You · \(rel)"))
                            .font(Theme.Typography.cardTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    } else {
                        Text(L10n.t("你", "You"))
                            .font(Theme.Typography.cardTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }

                    if let gapText = scoreGapText {
                        Text(gapText)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(rank == 1 ? Theme.Colors.ember : Theme.Colors.textMuted)
                    }
                }

                Spacer()

                if let score = scoreText {
                    Text(score)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            } else {
                // Uncertified state for the selected lift/exercise
                Image(systemName: "shield.slash.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Colors.textMuted)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("\(target.displayName)未认证", "\(target.displayName) Uncertified"))
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(L10n.t("认证试举后即可上榜", "Verify your lift to rank on the leaderboard"))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                Spacer()

                Button {
                    onCertifyTapped()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 12))
                        Text(L10n.t("上铁证", "Submit Proof"))
                            .font(Theme.Typography.cardTitle)
                    }
                    .foregroundStyle(Theme.Colors.ember)
                    .padding(.horizontal, Theme.Spacing.base)
                    .padding(.vertical, Theme.Spacing.xs * 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .fill(Theme.Colors.ember.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .strokeBorder(Theme.Colors.ember, lineWidth: Theme.Border.hairline)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.ember, lineWidth: Theme.Border.certified)
        )
    }
}

// MARK: - Empty State View

struct LeaderboardEmptyStateView: View {
    var message: String = L10n.t("虚位以待，上铁证成为首个上榜者", "Unclaimed. Submit proof to claim #1.")
    var onCertifyTapped: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.base) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.textMuted)

            VStack(spacing: Theme.Spacing.xs) {
                Text(message)
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Text(L10n.t("完成训练并提交视频，经同炉铁友见证后上榜", "Complete workout with video proof to rank."))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
            }

            if let onCertifyTapped = onCertifyTapped {
                Button {
                    onCertifyTapped()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 13))
                        Text(L10n.t("上铁证", "Submit Proof"))
                            .font(Theme.Typography.cardTitle)
                    }
                    .foregroundStyle(Theme.Colors.ember)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .fill(Theme.Colors.ember.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .strokeBorder(Theme.Colors.ember, lineWidth: Theme.Border.hairline)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.sm)
            }
        }
        .padding(Theme.Spacing.xl)
    }
}
