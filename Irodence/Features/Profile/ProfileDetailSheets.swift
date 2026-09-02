import SwiftUI
import Charts
import PhotosUI

// MARK: - 1. Body Progress Sheet (体重与体型记录)

struct BodyProgressSheet: View {
    @ObservedObject var service: ProfileService
    @ObservedObject var progress: ProgressService
    let library: ExerciseService

    @Environment(\.dismiss) private var dismiss
    @State private var showBodyweightPrompt = false
    @State private var bodyweightInput = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    // Bodyweight Chart Card
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("体重走势", "Bodyweight Trend"))
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text(L10n.t("用于校准力量分与体力量比", "Calibrates DOTS & relative strength"))
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }

                            Spacer()

                            Button {
                                bodyweightInput = service.profile?.bodyweightKg.map { String(format: "%.1f", $0) } ?? ""
                                showBodyweightPrompt = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(Theme.Typography.label)
                                    Text(L10n.t("记录体重", "Log Weight"))
                                        .font(Theme.Typography.label)
                                }
                                .foregroundStyle(Theme.Colors.ember)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, Theme.Spacing.xs / 2)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                                        .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if progress.bodyweightLogs.count >= 2 {
                            Chart(progress.bodyweightLogs) { log in
                                LineMark(
                                    x: .value(L10n.t("日期", "Date"), log.loggedAt, unit: .day),
                                    y: .value(L10n.t("体重", "Weight"), log.weightKg)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Theme.Colors.ember)

                                PointMark(
                                    x: .value(L10n.t("日期", "Date"), log.loggedAt, unit: .day),
                                    y: .value(L10n.t("体重", "Weight"), log.weightKg)
                                )
                                .symbolSize(24)
                                .foregroundStyle(Theme.Colors.ember)
                            }
                            .chartYScale(domain: bodyweightDomain)
                            .chartYAxis {
                                AxisMarks(position: .leading) { _ in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                        .foregroundStyle(Theme.Colors.borderHairline)
                                    AxisValueLabel()
                                        .foregroundStyle(Theme.Colors.textMuted)
                                        .font(Theme.Typography.caption)
                                }
                            }
                            .chartXAxis {
                                AxisMarks { _ in
                                    AxisValueLabel(format: .dateTime.month().day())
                                        .foregroundStyle(Theme.Colors.textMuted)
                                        .font(Theme.Typography.caption)
                                }
                            }
                            .frame(height: 160)
                            .padding(.vertical, Theme.Spacing.xs)
                        }

                        if progress.bodyweightLogs.isEmpty {
                            VStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "scalemass")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .padding(.top, Theme.Spacing.xs)

                                Text(L10n.t("暂无体重记录", "No Bodyweight Entries Yet"))
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundStyle(Theme.Colors.textSecondary)

                                Text(L10n.t("记录晨起空腹体重，精确计算力量分 (DOTS) 与 1RM 相对强度。", "Log morning bodyweight to calculate accurate DOTS score and relative strength."))
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, Theme.Spacing.sm)

                                Button {
                                    bodyweightInput = service.profile?.bodyweightKg.map { String(format: "%.1f", $0) } ?? ""
                                    showBodyweightPrompt = true
                                } label: {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Image(systemName: "plus")
                                        Text(L10n.t("记录今日体重", "Log Today's Weight"))
                                    }
                                    .font(Theme.Typography.label)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, Theme.Spacing.sm)
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
                                .padding(.top, Theme.Spacing.xs / 2)
                                .padding(.bottom, Theme.Spacing.xs)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.control)
                                    .fill(Theme.Colors.surfaceSunken.opacity(0.5))
                            )
                        } else {
                            VStack(spacing: Theme.Spacing.xs) {
                                ForEach(progress.bodyweightLogs.prefix(5)) { log in
                                    HStack {
                                        Text("\(formatKg(log.weightKg)) kg")
                                            .font(Theme.Typography.cardTitle)
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                        Spacer()
                                        Text(log.loggedAt, format: .dateTime.month().day().hour().minute())
                                            .font(Theme.Typography.caption)
                                            .foregroundStyle(Theme.Colors.textMuted)
                                    }
                                    .padding(.vertical, 4)
                                    Divider().background(Theme.Colors.borderHairline)
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
                            .strokeBorder(Theme.Colors.borderHairline, lineWidth: Theme.Border.hairline)
                    )

                    // Progress Photos Card
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        ProgressPhotosSection()
                    }
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .fill(Theme.Colors.surfaceRaised)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .strokeBorder(Theme.Colors.borderHairline, lineWidth: Theme.Border.hairline)
                    )
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Colors.surfaceBase.ignoresSafeArea())
            .navigationTitle(L10n.t("身体与体型", "Body & Progress"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("关闭", "Close")) { dismiss() }
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .alert(L10n.t("记录体重 (kg)", "Log Weight (kg)"), isPresented: $showBodyweightPrompt) {
                TextField("kg", text: $bodyweightInput)
                    .keyboardType(.decimalPad)
                Button(L10n.t("保存", "Save")) {
                    let bw = Double(bodyweightInput.replacingOccurrences(of: ",", with: ".")) ?? 0
                    Task {
                        if await progress.logBodyweight(bw) {
                            await service.load(library: library)
                        }
                    }
                }
                Button(L10n.t("取消", "Cancel"), role: .cancel) {}
            }
        }
    }

    private var bodyweightDomain: ClosedRange<Double> {
        let values = progress.bodyweightLogs.map(\.weightKg)
        let lo = (values.min() ?? 40) - 2
        let hi = (values.max() ?? 100) + 2
        return lo...hi
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - 2. Strength Standards Sheet (力量等级)

struct StrengthStandardsSheet: View {
    let profile: Profile
    @ObservedObject var service: ProfileService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Hero Summary (High-res badge + overall score)
                    if let sex = profile.sex, let bw = profile.bodyweightKg,
                       let totalDots = calculatedTotalDots(sex: sex, bw: bw, heightCm: profile.heightCm, ageYears: profile.ageYears) {
                        let overallTier = StrengthStandards.overallTier(bestLifts: service.bestLifts, bodyweightKg: bw, sex: sex, heightCm: profile.heightCm, ageYears: profile.ageYears)
                        VStack(spacing: 12) {
                            // High-Res Badge with Glow
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                overallTier.color.opacity(0.35),
                                                overallTier.color.opacity(0.08),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 15,
                                            endRadius: 55
                                        )
                                    )
                                    .frame(width: 110, height: 110)

                                Image(overallTier.assetImageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .strokeBorder(overallTier.color.opacity(0.6), lineWidth: 2)
                                    )
                                    .shadow(color: overallTier.color.opacity(0.4), radius: 16)
                            }
                            .metallicSheen(trigger: true, duration: 0.9, delay: 0.2)

                            // Tier Name
                            Text(overallTier.displayName)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(overallTier.color)

                            // Numeric Score Pill
                            HStack(spacing: 8) {
                                Text(L10n.t("综合力量分: \(String(format: "%.0f", totalDots))", "Overall Strength Score: \(String(format: "%.0f", totalDots))"))
                                    .font(.system(size: 15.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.Colors.textPrimary)

                                StrengthScoreInfoButton()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.surfaceSunken, in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .fill(Theme.Colors.surfaceRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                    }

                    // 2. Core Lifts Breakdown
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L10n.t("四大核心动作单项力量分", "Core Lifts Strength Scores"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)

                        if let sex = profile.sex, let bw = profile.bodyweightKg {
                            VStack(spacing: 0) {
                                ForEach(Array(CoreLift.allCases.enumerated()), id: \.element) { index, lift in
                                    if let best = service.bestLifts[lift] {
                                        TierCardView(lift: lift, est1RM: best.est1RM, sex: sex, bodyweightKg: bw, heightCm: profile.heightCm, ageYears: profile.ageYears)
                                    } else {
                                        HStack {
                                            Text(lift.displayName)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(Theme.Colors.textSecondary)
                                            Spacer()
                                            Text(L10n.t("尚未记录", "No Record"))
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundStyle(Theme.Colors.textMuted)
                                        }
                                        .padding(.vertical, 12)
                                    }

                                    if index < CoreLift.allCases.count - 1 {
                                        Divider()
                                            .background(Theme.Colors.borderHairline)
                                    }
                                }
                            }
                        } else {
                            Text(L10n.t("设置性别与体重后自动计算力量标准", "Set your sex and weight to unlock strength levels"))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .padding(.vertical, 8)
                        }
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

                    // 3. Tier List Roadmap
                    let userOverallTier: StrengthTier? = {
                        guard let sex = profile.sex, let bw = profile.bodyweightKg else { return nil }
                        return StrengthStandards.overallTier(bestLifts: service.bestLifts, bodyweightKg: bw, sex: sex, heightCm: profile.heightCm, ageYears: profile.ageYears)
                    }()

                    StrengthTierListView(currentTier: userOverallTier)

                    Text(L10n.t(
                        "评分算法基于国际通用 DOTS (Dynamic Objective Total Scoring) 公式",
                        "Scoring algorithm based on international DOTS (Dynamic Objective Total Scoring) formula"
                    ))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Theme.Colors.surfaceBase.ignoresSafeArea())
            .navigationTitle(L10n.t("力量等级与力量分", "Strength Standards"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("关闭", "Close")) { dismiss() }
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private func calculatedTotalDots(sex: Sex, bw: Double, heightCm: Double? = nil, ageYears: Int? = nil) -> Double? {
        var totalDots = 0.0
        var count = 0
        for lift in CoreLift.allCases {
            if let best = service.bestLifts[lift] {
                totalDots += DOTSCalculator.score(liftedKg: best.est1RM, bodyweightKg: bw, sex: sex, heightCm: heightCm, ageYears: ageYears)
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return totalDots
    }
}

/// A breakdown card for a single core lift tier
struct TierCardView: View {
    let lift: CoreLift
    let est1RM: Double
    let sex: Sex
    let bodyweightKg: Double
    let heightCm: Double?
    let ageYears: Int?

    private var calculatedDots: Double {
        DOTSCalculator.score(liftedKg: est1RM, bodyweightKg: bodyweightKg, sex: sex, heightCm: heightCm, ageYears: ageYears)
    }

    private var tier: StrengthTier {
        StrengthStandards.tier(for: calculatedDots, lift: lift, sex: sex)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(lift.displayName)
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(tier.displayName)
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textOnEmber)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.ember, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))
                }
                Text("1RM: \(formatKg(est1RM)) kg")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n.t("力量分", "Score"))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
                Text(String(format: "%.0f", calculatedDots))
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(Theme.Colors.ember)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - 3. Personal Records Sheet (个人最佳纪录)

struct PersonalRecordsSheet: View {
    @ObservedObject var service: ProfileService
    let library: ExerciseService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    let displayPRs = service.allPRs.isEmpty ? [
                        PersonalRecord(id: UUID(), userID: UUID(), exerciseID: ExerciseService.defaultExercises[0].id, weightKg: 130.0, reps: 3, estimated1RM: 140.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 2)),
                        PersonalRecord(id: UUID(), userID: UUID(), exerciseID: ExerciseService.defaultExercises[1].id, weightKg: 90.0, reps: 4, estimated1RM: 100.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 4)),
                        PersonalRecord(id: UUID(), userID: UUID(), exerciseID: ExerciseService.defaultExercises[2].id, weightKg: 160.0, reps: 3, estimated1RM: 175.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 7)),
                        PersonalRecord(id: UUID(), userID: UUID(), exerciseID: ExerciseService.defaultExercises[3].id, weightKg: 55.0, reps: 3, estimated1RM: 60.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 10)),
                        PersonalRecord(id: UUID(), userID: UUID(), exerciseID: ExerciseService.defaultExercises[4].id, weightKg: 80.0, reps: 6, estimated1RM: 96.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 12)),
                        PersonalRecord(id: UUID(), userID: UUID(), exerciseID: ExerciseService.defaultExercises[17].id, weightKg: 25.0, reps: 8, estimated1RM: 31.7, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 15))
                    ] : service.allPRs

                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(displayPRs) { pr in
                                let exerciseName = library.exercises.first(where: { $0.id == pr.exerciseID })?.displayName
                                    ?? ExerciseService.defaultExercises.first(where: { $0.id == pr.exerciseID })?.displayName
                                    ?? L10n.t("动作", "Exercise")
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(exerciseName)
                                            .font(Theme.Typography.cardTitle)
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                        Text(pr.achievedAt, format: .dateTime.year().month().day())
                                            .font(Theme.Typography.caption)
                                            .foregroundStyle(Theme.Colors.textMuted)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                                            Text("1RM: ")
                                                .font(Theme.Typography.caption)
                                                .foregroundStyle(Theme.Colors.textMuted)
                                            Text("\(formatKg(pr.estimated1RM)) kg")
                                                .font(Theme.Typography.cardTitle)
                                                .foregroundStyle(Theme.Colors.ember)
                                        }
                                        Text("\(formatKg(pr.weightKg)) kg × \(pr.reps)")
                                            .font(Theme.Typography.caption)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }
                                }
                                .padding(Theme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                                        .fill(Theme.Colors.surfaceRaised)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                                        .strokeBorder(Theme.Colors.borderHairline, lineWidth: Theme.Border.hairline)
                                )
                            }
                        }
                    }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Colors.surfaceBase.ignoresSafeArea())
            .navigationTitle(L10n.t("个人最佳纪录 (PR)", "Personal Best Records"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("关闭", "Close")) { dismiss() }
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - 4. App Settings Sheet

enum LegalURLs {
    static let privacyPolicy = URL(string: "https://irodence.app/privacy")!
    static let termsOfService = URL(string: "https://irodence.app/terms")!
}

struct OpenSourceLicensesView: View {
    struct LicenseItem: Identifiable {
        let id = UUID()
        let name: String
        let author: String
        let licenseType: String
        let repository: String
        let description: String
    }

    private let licenses: [LicenseItem] = [
        LicenseItem(
            name: "Supabase Swift",
            author: "Supabase Inc.",
            licenseType: "MIT License",
            repository: "github.com/supabase/supabase-swift",
            description: "Postgres backend, Realtime subscription channels, Auth and Storage client."
        ),
        LicenseItem(
            name: "Pow (SwiftUI Transitions)",
            author: "Emerge Tools",
            licenseType: "MIT License",
            repository: "github.com/EmergeTools/Pow",
            description: "Delightful SwiftUI animations, haptics, and forge strike effect transitions."
        ),
        LicenseItem(
            name: "Vortex (Particle System)",
            author: "Paul Hudson",
            licenseType: "MIT License",
            repository: "github.com/twostraws/Vortex",
            description: "High-performance SwiftUI ember sparks and particle physics engine."
        ),
        LicenseItem(
            name: "Swift Crypto",
            author: "Apple Inc.",
            licenseType: "Apache License 2.0",
            repository: "github.com/apple/swift-crypto",
            description: "Cryptographic SHA-256 digital fingerprint hashing for proof video integrity."
        ),
        LicenseItem(
            name: "Smiley Sans 站酷得意黑",
            author: "atelier anchor (ooooo.ooo)",
            licenseType: "SIL Open Font License 1.1",
            repository: "github.com/atelier-anchor/smiley-sans",
            description: "Condensed humanist sans-serif display font for forge stat numerals and tiers."
        )
    ]

    var body: some View {
        List {
            ForEach(licenses) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Spacer()

                        Text(item.licenseType)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Colors.ember)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: 4))
                    }

                    Text(item.author)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Colors.textMuted)

                    Text(item.description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Theme.Colors.textSecondary)

                    Text(item.repository)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .padding(.vertical, 4)
                .listRowBackground(Theme.Colors.surfaceRaised)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.surfaceBase.ignoresSafeArea())
        .navigationTitle(L10n.t("开源许可", "Open Source Licenses"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppSettingsSheet: View {
    var service: ProfileService? = nil
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var workoutManager: WorkoutManager

    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue
    @AppStorage(TextSizePreference.storageKey) private var textSize = TextSizePreference.standard.rawValue
    @AppStorage(AppThemeMode.storageKey) private var themeMode = AppThemeMode.dark.rawValue

    @Environment(\.dismiss) private var dismiss
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showDeleteAccountAlert = false
    @State private var showDevBadgeShowcase = false
    @State private var showMockOnboardingFlow = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(L10n.t("偏好设置", "Preferences")).font(Theme.Typography.label).foregroundStyle(Theme.Colors.textMuted)) {
                    // Appearance Mode (Dark / Light / System)
                    Picker(L10n.t("外观模式", "Appearance"), selection: $themeMode) {
                        ForEach(AppThemeMode.allCases) { mode in
                            Label(mode.displayName, systemImage: mode.iconName)
                                .tag(mode.rawValue)
                        }
                    }

                    // Language Picker
                    Picker(L10n.t("语言", "Language"), selection: $language) {
                        ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                            Text(lang.displayName).tag(lang.rawValue)
                        }
                    }

                    // Text Size Preference
                    Picker(L10n.t("字号大小", "Text Size"), selection: $textSize) {
                        ForEach(TextSizePreference.allCases, id: \.rawValue) { pref in
                            Text(pref.displayName).tag(pref.rawValue)
                        }
                    }

                    // Live Text Size Preview
                    HStack {
                        Text(L10n.t("字号预览", "Preview"))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textMuted)
                        Spacer()
                        Text(L10n.t("铁证 · 铸就钢铁之躯", "Irodence · Forge of Strength"))
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.ember)
                    }

                    // Rest Timer Default
                    Picker(L10n.t("默认组间休息", "Default Rest Timer"), selection: $workoutManager.restDurationSeconds) {
                        ForEach([60.0, 90.0, 120.0, 180.0, 300.0], id: \.self) { seconds in
                            Text(restLabel(seconds)).tag(seconds)
                        }
                    }
                }
                .listRowBackground(Theme.Colors.surfaceRaised)

                #if DEBUG
                // Developer Tools & Simulation Section
                Section(header: Text(L10n.t("开发者与模拟体验 (Dev & Simulation)", "Developer & Simulation")).font(Theme.Typography.label).foregroundStyle(Theme.Colors.ember)) {
                    Button {
                        showMockOnboardingFlow = true
                    } label: {
                        HStack {
                            Label(
                                L10n.t("🚀 完整新用户开箱模拟流程", "🚀 Mock New User Onboarding Flow"),
                                systemImage: "sparkles.rectangle.stack.fill"
                            )
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.ember)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }

                    Button {
                        showDevBadgeShowcase = true
                    } label: {
                        HStack {
                            Label(L10n.t("🛠 锻造勋章与金属反光展台", "🛠 Badge & Sheen Showcase"), systemImage: "shield.checkered")
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }
                }
                .listRowBackground(Theme.Colors.surfaceRaised)
                #endif

                Section(header: Text(L10n.t("帮助与教程", "Help & Guides")).font(Theme.Typography.label).foregroundStyle(Theme.Colors.textMuted)) {
                    Button {
                        UserDefaults.standard.set(false, forKey: "hasCompletedInAppTour")
                        dismiss()
                    } label: {
                        HStack {
                            Label(L10n.t("重新播放应用交互导览", "Replay App Feature Tour"), systemImage: "sparkles")
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }
                }
                .listRowBackground(Theme.Colors.surfaceRaised)

                Section(header: Text(L10n.t("法律与隐私", "Legal & Privacy")).font(Theme.Typography.label).foregroundStyle(Theme.Colors.textMuted)) {
                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        HStack {
                            Text(L10n.t("隐私政策", "Privacy Policy"))
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }

                    Button {
                        showTermsOfService = true
                    } label: {
                        HStack {
                            Text(L10n.t("服务条款", "Terms of Service"))
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }

                    NavigationLink(L10n.t("开源许可", "Open Source Licenses")) {
                        OpenSourceLicensesView()
                    }
                }
                .listRowBackground(Theme.Colors.surfaceRaised)

                Section {
                    Button(role: .destructive) {
                        dismiss()
                        Task { await authService.signOut() }
                    } label: {
                        HStack {
                            Spacer()
                            Text(L10n.t("退出登录", "Sign Out"))
                                .font(Theme.Typography.cardTitle)
                            Spacer()
                        }
                    }

                    Button(role: .destructive) {
                        showDeleteAccountAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(L10n.t("注销并彻底清除所有数据与视频", "Delete Account & Purge All Data"))
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.danger)
                            Spacer()
                        }
                    }
                }
                .listRowBackground(Theme.Colors.surfaceRaised)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.surfaceBase.ignoresSafeArea())
            .navigationTitle(L10n.t("应用设置", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("关闭", "Close")) { dismiss() }
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            #if DEBUG
            .sheet(isPresented: $showDevBadgeShowcase) {
                DevBadgeShowcaseSheet()
            }
            .fullScreenCover(isPresented: $showMockOnboardingFlow) {
                MockOnboardingFlowView()
            }
            #endif
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView()
            }
            .alert(L10n.t("确定要彻底注销账号吗？", "Permanently Delete Account?"), isPresented: $showDeleteAccountAlert) {
                Button(L10n.t("取消", "Cancel"), role: .cancel) {}
                Button(L10n.t("确认彻底注销", "Confirm & Delete"), role: .destructive) {
                    dismiss()
                    Task {
                        try? await authService.deleteAccount()
                    }
                }
            } message: {
                Text(L10n.t("根据安全与隐私规范，注销账号将彻底从云端物理清除所有试举视频、证词与训练档案，此操作不可恢复。", "All videos, proofs, and workout data will be permanently purged from the servers. This action cannot be undone."))
            }
        }
    }

    private func restLabel(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Dev Badge & Sheen Showcase Sheet

struct DevBadgeShowcaseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: StrengthTier = .hundredFold
    @State private var sheenTrigger = true
    @State private var showSimulatedReveal = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    featuredBadgeCard
                    actionButtons
                    tierGrid
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Colors.surfaceBase.ignoresSafeArea())
            .navigationTitle(L10n.t("徽章与反光展台", "Badge & Sheen Showcase"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("完成", "Done")) { dismiss() }
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
            .fullScreenCover(isPresented: $showSimulatedReveal) {
                AchievementReveal(
                    achievement: AchievementCatalog.tierUp(tier: selectedTier, lift: nil),
                    onDismiss: { showSimulatedReveal = false }
                )
            }
        }
    }

    private var featuredBadgeCard: some View {
        VStack(spacing: 16) {
            ZStack {
                // Ambient Radial Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                selectedTier.color.opacity(0.35),
                                selectedTier.color.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 110
                        )
                    )
                    .frame(width: 220, height: 220)

                Image(selectedTier.assetImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 175, height: 175)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(selectedTier.color.opacity(0.7), lineWidth: 2.5)
                    )
                    .shadow(color: selectedTier.color.opacity(0.45), radius: 28, y: 6)
            }
            .metallicSheen(trigger: sheenTrigger, duration: 0.9, delay: 0.1)
            .onTapGesture {
                sheenTrigger.toggle()
                ForgeHaptics.strike()
            }

            VStack(spacing: 6) {
                Text(selectedTier.displayName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(selectedTier.color)

                Text(L10n.t("点击勋章触发金属高光反射", "Tap badge to trigger specular sheen reflection"))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                sheenTrigger.toggle()
                ForgeHaptics.strike()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(L10n.t("闪光扫光", "Flash Sheen"))
                }
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Theme.Colors.emberDeep)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.Colors.ember, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
            }

            Button {
                showSimulatedReveal = true
            } label: {
                HStack {
                    Image(systemName: "trophy.fill")
                    Text(L10n.t("弹窗全屏测试", "Test Modal"))
                }
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline))
            }
        }
    }

    private var tierGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("全部 6 大锻造段位 (点击切换)", "All 6 Forge Tiers (Tap to Switch)"))
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Theme.Colors.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(StrengthTier.allCases, id: \.self) { tier in
                    tierItemCard(tier)
                }
            }
        }
    }

    private func tierItemCard(_ tier: StrengthTier) -> some View {
        let isSelected = selectedTier == tier
        return Button {
            selectedTier = tier
            sheenTrigger.toggle()
            ForgeHaptics.selection()
        } label: {
            HStack(spacing: 10) {
                Image(tier.assetImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(tier.color.opacity(0.5), lineWidth: 1)
                    )
                    .metallicSheen(trigger: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.displayName)
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(isSelected ? Theme.Colors.ember : Theme.Colors.textPrimary)
                }
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Theme.Colors.surfaceSunken : Theme.Colors.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(isSelected ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
            )
        }
        .buttonStyle(.plain)
    }
}
