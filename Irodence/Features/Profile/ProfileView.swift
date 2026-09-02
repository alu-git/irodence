import SwiftUI

/// Profile tab with forged-metal tier representation, 力量分 details,
/// and core navigation feature cards according to IRODENCE_DESIGN.md.
struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var library: ExerciseService
    @EnvironmentObject private var workoutManager: WorkoutManager
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    @StateObject private var service: ProfileService
    @StateObject private var progress = ProgressService()
    private let userID: UUID

    // Sheet presentation triggers
    @State private var showEditProfileSheet = false
    @State private var showBodyProgressSheet = false
    @State private var showWorkoutHistorySheet = false
    @State private var showStrengthStandardsSheet = false
    @State private var showPersonalRecordsSheet = false
    @State private var showAppSettingsSheet = false

    init(userID: UUID) {
        self.userID = userID
        _service = StateObject(wrappedValue: ProfileService(userID: userID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md + 4) {
                    if let profile = service.profile {
                        // MARK: - 1. Top Profile Header Card (Tap to Edit)
                        headerCard(profile)
                            .onTapGesture { showEditProfileSheet = true }

                        // MARK: - 2. Navigation Feature Cards
                        VStack(spacing: 10) {
                            // Card A: 锻造阶梯与力量分
                            strengthStandardsCard(profile)
                                .onTapGesture { showStrengthStandardsSheet = true }

                            // Card B: 历史训练记录
                            workoutHistoryCard
                                .onTapGesture { showWorkoutHistorySheet = true }

                            // Card C: 身体与进度
                            bodyProgressCard(profile)
                                .onTapGesture { showBodyProgressSheet = true }

                            // Card D: 个人最佳纪录 (PR)
                            personalRecordsCard
                                .onTapGesture { showPersonalRecordsSheet = true }

                            // Card E: 应用设置
                            settingsCard
                                .onTapGesture { showAppSettingsSheet = true }
                        }
                        .padding(.horizontal, Theme.Spacing.md)

                        // MARK: - 3. Localized Developer & Testing Tools
                        #if DEBUG
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            DebugPreviewSection(userID: userID)
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
                        .padding(.horizontal, Theme.Spacing.md)
                        #endif

                        // Version footer
                        Text(L10n.t("铁证 Irodence · v\(appVersion)", "Irodence · v\(appVersion)"))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .padding(.top, 4)

                        // Space for floating tab bar
                        Color.clear.frame(height: 70)

                    } else if service.isLoading {
                        VStack(spacing: Theme.Spacing.md) {
                            ForgeLoadingView(L10n.t("加载资料中…", "Loading profile…"))
                        }
                        .padding(.top, Theme.Spacing.xl * 2)
                    } else {
                        VStack(spacing: Theme.Spacing.md) {
                            Text(L10n.t("加载个人资料失败", "Failed to load profile"))
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(Theme.Colors.textMuted)
                            Button(L10n.t("重新加载", "Reload")) {
                                Task { await service.load(library: library) }
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.Colors.emberDeep)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(Theme.Colors.ember, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                        }
                        .padding(.top, Theme.Spacing.xl * 2)
                    }
                }
                .padding(.vertical, Theme.Spacing.md)
            }
            .background(Theme.Colors.surfaceBase.ignoresSafeArea())
            .navigationTitle(L10n.t("我的", "Profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L10n.t("我的", "Profile"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
            .refreshable {
                async let a: Void = service.load(library: library)
                async let b: Void = progress.loadBodyweightLogs()
                _ = await (a, b)
            }
            .task {
                async let a: Void = service.load(library: library)
                async let b: Void = progress.loadBodyweightLogs()
                _ = await (a, b)
            }
            // MARK: - Sheets
            .sheet(isPresented: $showEditProfileSheet) {
                if let profile = service.profile {
                    EditProfileSheet(profile: profile, service: service)
                }
            }
            .sheet(isPresented: $showWorkoutHistorySheet) {
                WorkoutHistorySheet(userID: userID)
            }
            .sheet(isPresented: $showBodyProgressSheet) {
                BodyProgressSheet(service: service, progress: progress, library: library)
            }
            .sheet(isPresented: $showStrengthStandardsSheet) {
                if let profile = service.profile {
                    StrengthStandardsSheet(profile: profile, service: service)
                }
            }
            .sheet(isPresented: $showPersonalRecordsSheet) {
                PersonalRecordsSheet(service: service, library: library)
            }
            .sheet(isPresented: $showAppSettingsSheet) {
                AppSettingsSheet(service: service)
            }
        }
    }

    private var workoutHistoryCard: some View {
        featureRow(
            title: L10n.t("历史训练记录", "Workout History"),
            subtitle: L10n.t("查看所有完成的训练与详细组数", "View all completed workouts & set logs"),
            icon: "clock.arrow.circlepath",
            iconColor: Theme.Colors.textPrimary
        )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Header Card

    private func headerCard(_ profile: Profile) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: 14) {
                ZStack {
                    if let avatarURL = profile.avatarURL, let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Theme.Colors.surfaceSunken)
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Theme.Colors.surfaceSunken)
                            .frame(width: 64, height: 64)
                            .overlay {
                                Text(String(profile.displayName.prefix(1)).uppercased())
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(profile.displayName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Spacer()

                        HStack(spacing: 4) {
                            Text(L10n.t("编辑资料", "Edit"))
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(Theme.Colors.ember)
                    }

                    if let bio = profile.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(2)
                    } else {
                        Text(L10n.t("点击添加个人简介与体测数据", "Tap to add bio & body metrics"))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }

                    HStack(spacing: 6) {
                        if let sex = profile.sex {
                            badgeText(sex.displayName, icon: "person.fill")
                        }

                        if let age = profile.ageYears {
                            badgeText(L10n.t("\(age) 岁", "\(age) yrs"))
                        }

                        if let bw = profile.bodyweightKg {
                            badgeText("\(formatKg(bw)) kg")
                        }

                        if let height = profile.heightCm {
                            badgeText("\(Int(height)) cm")
                        }
                    }
                    .padding(.top, 2)
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
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
        .padding(.horizontal, Theme.Spacing.md)
    }

    private func badgeText(_ text: String, icon: String? = nil) -> some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
            }
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))
        .foregroundStyle(Theme.Colors.textSecondary)
    }

    // MARK: - Feature Cards

    private func bodyProgressCard(_ profile: Profile) -> some View {
        let subtitle = profile.bodyweightKg.map {
            L10n.t("当前体重: \(formatKg($0)) kg", "Bodyweight: \(formatKg($0)) kg")
        } ?? L10n.t("体重未设置 · 查看进度照片", "Weight not set · View progress photos")
        return featureRow(
            title: L10n.t("身体与进度", "Body & Progress"),
            subtitle: subtitle,
            icon: "scalemass.fill",
            iconColor: Theme.Colors.textPrimary
        )
    }

    private func strengthStandardsCard(_ profile: Profile) -> some View {
        let overallTier = StrengthStandards.overallTier(
            bestLifts: service.bestLifts,
            bodyweightKg: profile.bodyweightKg ?? 75.0,
            sex: profile.sex ?? .male,
            heightCm: profile.heightCm,
            ageYears: profile.ageYears
        )

        return HStack(spacing: 14) {
            Image(overallTier.assetImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(overallTier.color.opacity(0.6), lineWidth: 1.5)
                )
                .shadow(color: overallTier.color.opacity(0.3), radius: 6)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t("锻造阶梯与力量分", "Forge Tier & Strength Score"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                if let sex = profile.sex, let bw = profile.bodyweightKg,
                   let dots = calculatedTotalDots(sex: sex, bw: bw) {
                    HStack(spacing: 6) {
                        Text(overallTier.displayName)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(overallTier.color)
                        Text(L10n.t("· 综合力量分: \(String(format: "%.0f", dots))", "· Total Score: \(String(format: "%.0f", dots))"))
                            .font(.system(size: 13.5, weight: .regular))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                } else {
                    HStack(spacing: 6) {
                        Text(overallTier.displayName)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(overallTier.color)
                        Text(L10n.t("· 四大项标准与评分", "· Standards & Scoring"))
                            .font(.system(size: 13.5, weight: .regular))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textMuted)
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

    private var personalRecordsCard: some View {
        let subtitle = service.allPRs.isEmpty
            ? L10n.t("尚无 PR 纪录 · 完成训练解锁", "No PRs yet · Complete workouts to unlock")
            : L10n.t("\(service.allPRs.count) 项动作个人最佳突破", "\(service.allPRs.count) Personal Records broken")
        return featureRow(
            title: L10n.t("个人最佳纪录 (PR)", "Personal Records (PR)"),
            subtitle: subtitle,
            icon: "hammer.fill",
            iconColor: Theme.Colors.textPrimary
        )
    }

    private var settingsCard: some View {
        featureRow(
            title: L10n.t("应用设置", "App Settings"),
            subtitle: L10n.t("语言、字体、休息计时器与条款", "Language, text size, rest timer & legal"),
            icon: "gearshape.fill",
            iconColor: Theme.Colors.textSecondary
        )
    }

    private func featureRow(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(Theme.Colors.surfaceSunken)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(subtitle)
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textMuted)
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

    private func calculatedTotalDots(sex: Sex, bw: Double) -> Double? {
        var totalDots = 0.0
        var count = 0
        for lift in CoreLift.allCases {
            if let best = service.bestLifts[lift] {
                totalDots += DOTSCalculator.score(
                    liftedKg: best.est1RM,
                    bodyweightKg: bw,
                    sex: sex,
                    heightCm: service.profile?.heightCm,
                    ageYears: service.profile?.ageYears
                )
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return totalDots
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}
