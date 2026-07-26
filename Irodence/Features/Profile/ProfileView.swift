import SwiftUI
import Charts

/// Profile tab: strength tiers per core lift + sex/bodyweight settings
/// (both feed the DOTS calculation).
struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var library: ExerciseService
    @EnvironmentObject private var workoutManager: WorkoutManager
    @StateObject private var service: ProfileService
    @StateObject private var progress = ProgressService()
    private let userID: UUID

    @State private var showBodyweightPrompt = false
    @State private var bodyweightInput = ""
    @State private var showNamePrompt = false
    @State private var nameInput = ""

    // Same keys RootView reads — @AppStorage writes propagate live.
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue
    @AppStorage(TextSizePreference.storageKey) private var textSize = TextSizePreference.standard.rawValue

    init(userID: UUID) {
        self.userID = userID
        _service = StateObject(wrappedValue: ProfileService(userID: userID))
    }

    var body: some View {
        NavigationStack {
            List {
                if let profile = service.profile {
                    headerSection(profile)
                    settingsSection(profile)
                    preferencesSection
                    bodyweightSection
                    ProgressPhotosSection()
                    tierSection(profile)
                    legalSection
                    #if DEBUG
                    DebugPreviewSection(userID: userID)
                    #endif
                } else if service.isLoading {
                    Section { ProgressView() }
                } else {
                    Section {
                        Button("重新加载") {
                            Task { await service.load(library: library) }
                        }
                    }
                }

                Section {
                    Button("退出登录", role: .destructive) {
                        Task { await authService.signOut() }
                    }
                } header: {
                    Text("账户")
                } footer: {
                    Text("Irodence 铁证 · v\(appVersion)")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)
                }
            }
            .navigationTitle("我的")
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
            .alert("记录体重 (kg)", isPresented: $showBodyweightPrompt) {
                TextField("kg", text: $bodyweightInput)
                    .keyboardType(.decimalPad)
                Button("保存") {
                    let bw = Double(bodyweightInput.replacingOccurrences(of: ",", with: ".")) ?? 0
                    Task {
                        if await progress.logBodyweight(bw) {
                            await service.load(library: library) // refresh DOTS inputs
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .alert("修改昵称", isPresented: $showNamePrompt) {
                TextField("昵称", text: $nameInput)
                Button("保存") {
                    Task { await service.updateDisplayName(nameInput) }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    // MARK: - Sections

    private func headerSection(_ profile: Profile) -> some View {
        Section {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                    Text(String(profile.displayName.prefix(1)))
                        .font(.title3.bold())
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading) {
                    Text(profile.displayName).font(.title3.bold())
                    if let sex = profile.sex, let bw = profile.bodyweightKg {
                        Text("\(sex.displayName) · \(formatKg(bw)) kg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func settingsSection(_ profile: Profile) -> some View {
        Section("资料") {
            Button {
                nameInput = profile.displayName
                showNamePrompt = true
            } label: {
                HStack {
                    Text("昵称")
                    Spacer()
                    Text(profile.displayName)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.primary)

            Picker("性别", selection: sexBinding) {
                ForEach(Sex.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            Button {
                bodyweightInput = profile.bodyweightKg.map(formatKg) ?? ""
                showBodyweightPrompt = true
            } label: {
                HStack {
                    Text("体重")
                    Spacer()
                    Text(profile.bodyweightKg.map { "\(formatKg($0)) kg" } ?? "未设置")
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
        }
    }

    /// Writes through to the shared WorkoutManager so the change is live
    /// immediately; its didSet persists to UserDefaults for next launch.
    private var preferencesSection: some View {
        Section("设置") {
            Picker("语言", selection: $language) {
                ForEach(AppLanguage.allCases, id: \.self) {
                    Text($0.displayName).tag($0.rawValue)
                }
            }

            Picker("字体大小", selection: $textSize) {
                ForEach(TextSizePreference.allCases, id: \.self) {
                    Text($0.displayName).tag($0.rawValue)
                }
            }

            Picker("默认休息时长", selection: $workoutManager.restDurationSeconds) {
                ForEach([60.0, 90, 120, 180, 300], id: \.self) { seconds in
                    Text(restLabel(seconds)).tag(seconds)
                }
            }
        }
    }

    private func restLabel(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var sexBinding: Binding<Sex> {
        Binding(
            get: { service.profile?.sex ?? .male },
            set: { newSex in
                Task { await service.update(sex: newSex, bodyweightKg: service.profile?.bodyweightKg) }
            }
        )
    }

    @ViewBuilder
    private func tierSection(_ profile: Profile) -> some View {
        Section("力量等级") {
            if let sex = profile.sex, let bw = profile.bodyweightKg {
                ForEach(CoreLift.allCases, id: \.self) { lift in
                    if let best = service.bestLifts[lift] {
                        TierCardView(lift: lift, est1RM: best.est1RM, sex: sex, bodyweightKg: bw)
                    } else {
                        HStack {
                            Text(lift.displayName).font(.headline)
                            Spacer()
                            Text("完成一次训练后解锁")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Label("设置性别和体重后，这里会显示你的力量等级", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Dated bodyweight log — feeds DOTS and charts the trend.
    private var bodyweightSection: some View {
        Section("体重记录") {
            if progress.bodyweightLogs.count >= 2 {
                Chart(progress.bodyweightLogs) { log in
                    LineMark(
                        x: .value("日期", log.loggedAt, unit: .day),
                        y: .value("体重", log.weightKg)
                    )
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("日期", log.loggedAt, unit: .day),
                        y: .value("体重", log.weightKg)
                    )
                    .symbolSize(20)
                }
                .chartYScale(domain: bodyweightDomain)
                .frame(height: 140)
            }

            ForEach(progress.bodyweightLogs.suffix(3).reversed()) { log in
                HStack {
                    Text("\(formatKg(log.weightKg)) kg")
                        .font(.headline.monospacedDigit())
                    Spacer()
                    Text(log.loggedAt, format: .dateTime.month().day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                let recent = Array(progress.bodyweightLogs.suffix(3).reversed())
                for index in offsets {
                    Task { await progress.deleteBodyweightLog(recent[index].id) }
                }
            }

            Button {
                bodyweightInput = service.profile?.bodyweightKg.map(formatKg) ?? ""
                showBodyweightPrompt = true
            } label: {
                Label("记录今日体重", systemImage: "plus.circle")
            }
        }
    }

    private var bodyweightDomain: ClosedRange<Double> {
        let values = progress.bodyweightLogs.map(\.weightKg)
        let lo = (values.min() ?? 40) - 2
        let hi = (values.max() ?? 100) + 2
        return lo...hi
    }

    /// App Store requires an accessible privacy policy; these open the
    /// GitHub Pages-hosted copies in Safari.
    private var legalSection: some View {
        Section("法律与隐私") {
            Link("隐私政策", destination: LegalURLs.privacyPolicy)
            Link("服务条款", destination: LegalURLs.termsOfService)
        }
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

/// URLs of the hosted legal documents (GitHub Pages, `irodence-legal` repo,
/// content from docs/legal/ in this repo). Force-unwrapped: literals.
enum LegalURLs {
    static let privacyPolicy = URL(string: "https://andalu0906.github.io/irodence-legal/privacy-policy.html")!
    static let termsOfService = URL(string: "https://andalu0906.github.io/irodence-legal/terms-of-service.html")!
}

/// One core lift: DOTS score, tier badge, progress to next tier.
struct TierCardView: View {
    let lift: CoreLift
    let est1RM: Double
    let sex: Sex
    let bodyweightKg: Double

    private var dots: Double {
        DOTSCalculator.score(liftedKg: est1RM, bodyweightKg: bodyweightKg, sex: sex)
    }

    private var standing: (tier: StrengthTier, progress: Double, nextBoundary: Double?) {
        StrengthStandards.progressToNextTier(dots: dots, lift: lift, sex: sex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(lift.displayName).font(.headline)
                Spacer()
                Label(standing.tier.displayName, systemImage: standing.tier.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(standing.tier.color)
            }

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("估算 1RM").font(.caption2).foregroundStyle(.secondary)
                    Text("\(formatKg(est1RM)) kg").font(.title3.monospacedDigit().weight(.semibold))
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("DOTS").font(.caption2).foregroundStyle(.secondary)
                    Text(String(format: "%.0f", dots)).font(.title3.monospacedDigit().weight(.semibold))
                }
                Spacer()
            }

            ProgressView(value: standing.progress)
                .tint(standing.tier.color)

            if let next = standing.nextBoundary,
               let nextTier = StrengthTier(rawValue: standing.tier.rawValue + 1) {
                Text("距\(nextTier.displayName)还差 \(String(format: "%.0f", next - dots)) DOTS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("已达最高等级")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}
