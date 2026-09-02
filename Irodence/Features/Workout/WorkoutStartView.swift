import SwiftUI

/// Simplified Training (训练) tab home screen according to IRODENCE_DESIGN.md.
/// - Single-page structured layout with gym-grade, high-contrast, large mobile typography.
/// - Pinned & Favorite Templates section for instant 1-tap daily access.
/// - Promoted 24-Blueprint Forge Template Library with category filters and interactive previews.
/// - Exactly one filled-ember element per screen when active cycle exists.
struct WorkoutStartView: View {
    @EnvironmentObject private var manager: WorkoutManager
    @EnvironmentObject private var library: ExerciseService
    @StateObject private var crewService = CrewService()
    @ObservedObject private var favoritesManager = FavoriteTemplatesManager.shared
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    @State private var templates: [(template: WorkoutTemplate, exercises: [WorkoutTemplateExercise], lastUsed: Date?)] = []
    @State private var isLoadingTemplates = false
    @State private var weeklySessionCount: Int = 2
    @State private var showLibrarySheet = false
    @State private var showNewTemplateSheet = false
    @State private var previewTemplate: BuiltInTemplate?

    // Active program cycle state (nil = no active cycle)
    @State private var activeCycle: ActiveCycleInfo? = ActiveCycleInfo(
        programNameZh: "经典力量进阶周期",
        programNameEn: "Classic Strength Progression Cycle",
        currentWeek: 3,
        totalWeeks: 8,
        nextSessionNameZh: "推力日 · 卧推 5×5",
        nextSessionNameEn: "Push Day · Bench 5×5",
        crewTempBonus: 15
    )

    struct ActiveCycleInfo: Codable, Hashable {
        let programNameZh: String
        let programNameEn: String
        let currentWeek: Int
        let totalWeeks: Int
        let nextSessionNameZh: String
        let nextSessionNameEn: String
        let crewTempBonus: Int

        var programName: String { L10n.t(programNameZh, programNameEn) }
        var nextSessionName: String { L10n.t(nextSessionNameZh, nextSessionNameEn) }
    }

    private struct CachedTemplateItem: Codable {
        let template: WorkoutTemplate
        let exercises: [WorkoutTemplateExercise]
        let lastUsed: Date?
    }

    private var cacheKey: String {
        "workout_templates_v2_\(manager.userIDForTemplates.uuidString)"
    }

    private var favoritedBuiltInTemplates: [BuiltInTemplate] {
        BuiltInTemplate.all.filter { favoritesManager.isFavorite(id: $0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.surfaceBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. Header Row (Large & prominent)
                        headerRow

                        // 1.5 Crash / Unfinished Workout Auto-Recovery Card (Highest Priority)
                        if let draft = manager.savedDraft {
                            unfinishedWorkoutRecoveryCard(draft)
                        }

                        // 2. Resume Card (Only if active cycle) OR Promoted Library Card (Empty State 1)
                        if let cycle = activeCycle {
                            resumeCycleCard(cycle)
                        } else {
                            noCyclePromotedCard
                        }

                        // 3. Section: 我的与常练模板 (Favorites & Custom Templates)
                        myAndFavoriteTemplatesSection

                        // 4. Library Entry Row (Shown when active cycle is present)
                        if activeCycle != nil {
                            libraryEntryRow
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
            .sheet(isPresented: $showLibrarySheet) {
                TemplateLibraryView()
            }
            .sheet(isPresented: $showNewTemplateSheet) {
                TemplateLibraryView()
            }
            .sheet(item: $previewTemplate) { template in
                TemplatePreviewSheet(template: template) {
                    Task {
                        await library.loadIfNeeded()
                        await manager.startBuiltIn(template, library: library)
                    }
                }
            }
        }
    }

    // MARK: - 1. Header Row

    private var headerRow: some View {
        HStack(alignment: .center) {
            Text(L10n.t("训练", "Workout"))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            // Weekly session count: "本周 ×N" with hammer icon
            HStack(spacing: 6) {
                Text(L10n.t("本周 ×\(weeklySessionCount)", "This Week ×\(weeklySessionCount)"))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textSecondary)

                Image(systemName: "hammer.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.ember)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.Colors.surfaceRaised, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
            )
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    // MARK: - 1.5 Unfinished Workout Crash / Auto-Recovery Card

    private func unfinishedWorkoutRecoveryCard(_ draft: WorkoutManager.WorkoutDraft) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm + 2) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.arrow.circlepath")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)

                Text(L10n.t("检测到未完成的训练记录", "Unfinished Workout Found"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)

                Spacer()

                Button {
                    manager.discardDraft()
                } label: {
                    Text(L10n.t("放弃草稿", "Discard"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .buttonStyle(.forgePress)
            }

            Text(draft.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            let completed = draft.completedSetsCount
            let total = draft.totalSetsCount
            let mins = max(1, Int(draft.elapsedDuration / 60))

            Text(L10n.t("已进行 \(mins) 分钟 · 已完成 \(completed)/\(total) 组 · 数据已安全保全", "\(mins)m elapsed · \(completed)/\(total) sets done · Safely preserved"))
                .font(.system(size: 13.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.Colors.textSecondary)

            Button {
                manager.restoreDraft()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(L10n.t("继续本次训练", "Resume Workout"))
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(Theme.Colors.emberDeep)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(Theme.Colors.ember)
                )
            }
            .buttonStyle(.forgePress)
            .padding(.top, 4)
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
        .shadow(color: Color.black.opacity(0.4), radius: 10, y: 3)
    }

    // MARK: - 2. Resume Card (Active Cycle)

    private func resumeCycleCard(_ cycle: ActiveCycleInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Line 1: Cycle progression
            HStack(spacing: 6) {
                Text(cycle.programName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))

                Text(L10n.t("第 \(cycle.currentWeek) / \(cycle.totalWeeks) 周", "Week \(cycle.currentWeek) of \(cycle.totalWeeks)"))
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textMuted)
            }

            // Line 2: Next session name
            Text(cycle.nextSessionName)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            // Buttons: 继续训练 (Filled Ember) & 自由开练 (Subtle)
            HStack(spacing: 12) {
                Button {
                    startNextCycleWorkout(cycle)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(L10n.t("继续训练", "Continue"))
                            .font(.system(size: 16.5, weight: .bold))
                    }
                    .foregroundStyle(Theme.Colors.emberDeep)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .fill(Theme.Colors.ember)
                    )
                }
                .buttonStyle(.forgePress)

                Button {
                    Task { await manager.startEmpty() }
                } label: {
                    Text(L10n.t("自由开练", "Quick Start"))
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .fill(Theme.Colors.surfaceSunken)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                }
                .buttonStyle(.forgePress)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    // MARK: - Empty State 1: No Active Cycle Promoted Card

    private var noCyclePromotedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.Colors.ember)

                Text(L10n.t("经典锻造图纸库", "Template Library"))
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textMuted)
            }

            Text(L10n.t("精选 24 套经典力量图纸，即刻开练", "24 forged blueprints ready to start"))
                .font(.system(size: 14.5, weight: .regular))
                .foregroundStyle(Theme.Colors.textSecondary)

            Button {
                Task { await manager.startEmpty() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text(L10n.t("自由开练", "Quick Workout"))
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
        .onTapGesture {
            showLibrarySheet = true
        }
    }

    // MARK: - 3. Section: 我的与常练模板

    private var myAndFavoriteTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("常练图纸", "Favorite Routines"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()

                Button {
                    showLibrarySheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text(L10n.t("去挑选", "Explore"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Colors.ember)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.Colors.surfaceRaised, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)

            // Combined list of favorited built-in templates + user custom templates
            VStack(spacing: 11) {
                // 1. Favorited Built-In Templates
                ForEach(favoritedBuiltInTemplates) { template in
                    Button {
                        previewTemplate = template
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            // Star indicator
                            Image(systemName: "star.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.Colors.ember)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(template.name)
                                    .font(.system(size: 16.5, weight: .bold))
                                    .foregroundStyle(Theme.Colors.textPrimary)

                                HStack(spacing: 6) {
                                    Text(template.category.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Theme.Colors.ember)

                                    Text("·")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.Colors.textMuted)

                                    Text(L10n.t("约 \(template.estimatedMinutes) 分钟", "~\(template.estimatedMinutes)m"))
                                        .font(.system(size: 12.5, weight: .regular))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.template)
                                .fill(Theme.Colors.surfaceRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.template)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // 2. Custom User Templates
                ForEach(templates, id: \.template.id) { item in
                    Button {
                        Task {
                            await library.loadIfNeeded()
                            await manager.start(
                                from: item.template,
                                templateExercises: item.exercises,
                                library: library
                            )
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.template.name)
                                    .font(.system(size: 16.5, weight: .bold))
                                    .foregroundStyle(Theme.Colors.textPrimary)

                                Text(templateSubtitle(exercises: item.exercises, lastUsed: item.lastUsed))
                                    .font(.system(size: 12.5, weight: .regular))
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.template)
                                .fill(Theme.Colors.surfaceRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.template)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if favoritedBuiltInTemplates.isEmpty && templates.isEmpty {
                    Button {
                        showLibrarySheet = true
                    } label: {
                        HStack {
                            Text(L10n.t("前往图纸库，收藏常用训练模板", "Browse library to favorite a routine"))
                                .font(.system(size: 14.5, weight: .medium))
                                .foregroundStyle(Theme.Colors.textMuted)

                            Spacer()

                            Image(systemName: "books.vertical.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.Colors.ember)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.template)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 4. Library Entry Row

    private var libraryEntryRow: some View {
        Button {
            showLibrarySheet = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.ember.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.Colors.ember)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("经典锻造图纸库", "Forge Template Library"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(L10n.t("共 24 套经典力量与增肌图纸", "24 Built-In Routines"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.Colors.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers & Data Loading

    private func templateSubtitle(exercises: [WorkoutTemplateExercise], lastUsed: Date?) -> String {
        let names = exercises.prefix(3).compactMap { item -> String? in
            library.exercises.first(where: { $0.id == item.exerciseID })?.displayName
        }
        let listText = names.isEmpty ? L10n.t("核心复合动作", "Core Compound Lifts") : names.joined(separator: ", ")
        let relativeDay = formatRelativeLastUsed(lastUsed)
        return "\(listText) · \(relativeDay)"
    }

    private func formatRelativeLastUsed(_ date: Date?) -> String {
        guard let date = date else { return L10n.t("上次 昨天", "Last used yesterday") }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.t("今天使用过", "Used today")
        } else if calendar.isDateInYesterday(date) {
            return L10n.t("昨天使用过", "Used yesterday")
        } else {
            let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            if days <= 7 {
                return L10n.t("\(days) 天前使用", "\(days)d ago")
            } else {
                return date.formatted(date: .numeric, time: .omitted)
            }
        }
    }

    private func startNextCycleWorkout(_ cycle: ActiveCycleInfo) {
        Task {
            await library.loadIfNeeded()
            if let pushTemplate = BuiltInTemplate.all.first(where: { $0.id == "ppl_push_strength" }) {
                await manager.startBuiltIn(pushTemplate, library: library)
            } else {
                await manager.startEmpty()
            }
        }
    }

    private func loadData() async {
        guard !isLoadingTemplates else { return }
        isLoadingTemplates = true
        defer { isLoadingTemplates = false }

        let userID = manager.userIDForTemplates

        // Read local disk cache first
        if let cachedData = UserDefaults.standard.data(forKey: cacheKey),
           let cachedList = try? JSONDecoder().decode([CachedTemplateItem].self, from: cachedData),
           !cachedList.isEmpty {
            self.templates = cachedList.map { ($0.template, $0.exercises, $0.lastUsed) }
        }

        let workoutService = WorkoutService()
        async let crewTask: Void = crewService.loadUserCrew(userID: userID)
        async let templatesTask = workoutService.fetchTemplates(userID: userID)

        _ = await crewTask
        do {
            let remoteTemplates = try await templatesTask
            if !remoteTemplates.isEmpty {
                self.templates = remoteTemplates.map { ($0.template, $0.exercises, nil) }
                let encodableList = self.templates.map {
                    CachedTemplateItem(template: $0.template, exercises: $0.exercises, lastUsed: $0.lastUsed)
                }
                if let data = try? JSONEncoder().encode(encodableList) {
                    UserDefaults.standard.set(data, forKey: cacheKey)
                }
            }
        } catch {
            // Retain local cached templates
        }
    }
}
