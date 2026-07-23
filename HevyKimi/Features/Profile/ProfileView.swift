import SwiftUI

/// Profile tab: strength tiers per core lift + sex/bodyweight settings
/// (both feed the DOTS calculation).
struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var library: ExerciseService
    @StateObject private var service: ProfileService

    @State private var showBodyweightPrompt = false
    @State private var bodyweightInput = ""
    @State private var selectedSex: Sex = .male

    init(userID: UUID) {
        _service = StateObject(wrappedValue: ProfileService(userID: userID))
    }

    var body: some View {
        NavigationStack {
            List {
                if let profile = service.profile {
                    headerSection(profile)
                    settingsSection(profile)
                    tierSection(profile)
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
                }
            }
            .navigationTitle("我的")
            .refreshable { await service.load(library: library) }
            .task { await service.load(library: library) }
            .alert("输入体重 (kg)", isPresented: $showBodyweightPrompt) {
                TextField("kg", text: $bodyweightInput)
                    .keyboardType(.decimalPad)
                Button("保存") {
                    let bw = Double(bodyweightInput.replacingOccurrences(of: ",", with: "."))
                    Task { await service.update(sex: service.profile?.sex, bodyweightKg: bw) }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    // MARK: - Sections

    private func headerSection(_ profile: Profile) -> some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
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

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
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
