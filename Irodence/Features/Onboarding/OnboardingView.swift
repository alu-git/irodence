import SwiftUI

/// Gate between sign-in and the main app. Loads the profile once and routes
/// brand-new accounts (DB-trigger default profile, no sex set) through
/// OnboardingView before revealing the tabs. Fails open: if the profile
/// can't be fetched (offline, local preview session), we skip onboarding
/// rather than block the app.
struct OnboardingGateView: View {
    @StateObject private var service: ProfileService
    @State private var phase: Phase = .loading
    private let userID: UUID

    private enum Phase {
        case loading, onboarding, main
    }

    init(userID: UUID) {
        self.userID = userID
        _service = StateObject(wrappedValue: ProfileService(userID: userID))
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                VStack(spacing: 24) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                    ProgressView()
                }
            case .onboarding:
                OnboardingView(service: service) {
                    withAnimation { phase = .main }
                }
                .transition(.opacity)
            case .main:
                MainTabView(userID: userID)
                    .transition(.opacity)
            }
        }
        .task {
            await service.loadProfile()
            phase = service.needsOnboarding ? .onboarding : .main
        }
    }
}

/// First-run onboarding for new accounts: welcome → 昵称 → 性别 → 体重.
/// Sex + bodyweight feed the strength-standard/DOTS calculations, so they're
/// collected up front; both are skippable here and stay editable later under
/// 我的 → 资料.
struct OnboardingView: View {
    @ObservedObject var service: ProfileService
    let onFinished: () -> Void

    @State private var step: Step = .welcome
    @State private var name: String
    @State private var sex: Sex?
    @State private var bodyweightText = ""
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Step: Int {
        case welcome, name, sex, bodyweight
    }

    private enum Field {
        case name, bodyweight
    }

    init(service: ProfileService, onFinished: @escaping () -> Void) {
        self.service = service
        self.onFinished = onFinished
        _name = State(initialValue: service.profile?.displayName ?? "")
    }

    var body: some View {
        VStack(spacing: 24) {
            if step == .welcome {
                Spacer()
            } else {
                topBar
            }

            Group {
                switch step {
                case .welcome: welcomeStep
                case .name: nameStep
                case .sex: sexStep
                case .bodyweight: bodyweightStep
                }
            }
            .frame(maxHeight: .infinity)
            .id(step)
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))

            bottomButtons
        }
        .padding(.horizontal, 32)
        .animation(.default, value: step)
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(spacing: 16) {
            Button {
                back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 32, height: 32)
            }
            .foregroundStyle(.secondary)

            // Steps 昵称/性别/体重 — welcome has no bar
            HStack(spacing: 6) {
                ForEach(1..<4, id: \.self) { index in
                    Capsule()
                        .fill(index <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                }
            }

            // Balance the back button so the bar stays centered
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.top, 8)
    }

    private var bottomButtons: some View {
        VStack(spacing: 12) {
            Button(action: advance) {
                Group {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(primaryTitle)
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAdvance)

            if step == .sex || step == .bodyweight {
                Button("稍后再填", action: skipStep)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let error = service.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 16)
    }

    private var primaryTitle: LocalizedStringKey {
        switch step {
        case .welcome: return "开始"
        case .bodyweight: return "完成"
        default: return "继续"
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                Text("欢迎来到铁证")
                    .font(.largeTitle.bold())
                Text("记录训练，见证变强")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 20) {
                featureRow("dumbbell.fill", "记录训练", "每个动作的组数、重量、容量")
                featureRow("chart.line.uptrend.xyaxis", "力量等级", "DOTS 系数衡量你的真实水平")
                featureRow("trophy.fill", "好友排行", "和朋友一较高下")
            }
        }
    }

    private func featureRow(_ icon: String, _ title: LocalizedStringKey, _ subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var nameStep: some View {
        VStack(spacing: 16) {
            stepHeader("怎么称呼你？", subtitle: "其他用户会看到这个名字")

            TextField("昵称", text: $name)
                .font(.title3)
                .padding()
                .background(.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                .focused($focusedField, equals: .name)
                .submitLabel(.continue)
                .onSubmit(advance)
        }
    }

    private var sexStep: some View {
        VStack(spacing: 32) {
            stepHeader("你的性别", subtitle: "用于匹配力量等级标准")

            HStack(spacing: 16) {
                ForEach(Sex.allCases, id: \.self) { option in
                    sexCard(option)
                }
            }
        }
    }

    private func sexCard(_ option: Sex) -> some View {
        let selected = sex == option
        return Button {
            sex = option
        } label: {
            VStack(spacing: 12) {
                Image(systemName: option == .male ? "figure.stand" : "figure.dress")
                    .font(.system(size: 44))
                Text(option.displayName)
                    .font(.headline)
            }
            .foregroundStyle(selected ? Color.accentColor : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentColor.opacity(selected ? 0.15 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        selected ? Color.accentColor : Color.secondary.opacity(0.4),
                        lineWidth: selected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var bodyweightStep: some View {
        VStack(spacing: 16) {
            stepHeader("你的体重", subtitle: "用于 DOTS 系数计算，之后可随时修改")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("70", text: $bodyweightText)
                    .font(.system(size: 56, weight: .bold))
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .bodyweight)
                    .frame(maxWidth: 200)
                Text("kg")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stepHeader(_ title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.bottom, 16)
    }

    // MARK: - Navigation

    private var parsedBodyweight: Double? {
        let text = bodyweightText.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return Double(text)
    }

    private var canAdvance: Bool {
        guard !isSaving else { return false }
        switch step {
        case .welcome:
            return true
        case .name:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .sex:
            return sex != nil
        case .bodyweight:
            // Empty acts as skip; otherwise must parse into a sane range
            // (mirrors the bodyweight_kg CHECK constraint).
            guard !bodyweightText.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
            guard let bw = parsedBodyweight else { return false }
            return bw > 0 && bw < 500
        }
    }

    private func advance() {
        guard canAdvance else { return }
        switch step {
        case .welcome:
            step = .name
            focusedField = .name
        case .name:
            step = .sex
            focusedField = nil
        case .sex:
            step = .bodyweight
            focusedField = .bodyweight
        case .bodyweight:
            finish(saveBodyweight: true)
        }
    }

    private func back() {
        switch step {
        case .name: step = .welcome
        case .sex: step = .name
        case .bodyweight: step = .sex
        case .welcome: break
        }
    }

    private func skipStep() {
        switch step {
        case .sex:
            step = .bodyweight
            focusedField = .bodyweight
        case .bodyweight:
            finish(saveBodyweight: false)
        default:
            break
        }
    }

    /// 完成 always requires the save to succeed; 稍后再填 is best-effort and
    /// never traps the user (offline etc.) — anything missing stays editable
    /// in the profile tab.
    private func finish(saveBodyweight: Bool) {
        isSaving = true
        focusedField = nil
        Task {
            let ok = await service.completeOnboarding(
                name: name,
                sex: sex,
                bodyweightKg: saveBodyweight ? parsedBodyweight : nil
            )
            isSaving = false
            if ok || !saveBodyweight {
                service.skipOnboarding()
                onFinished()
            }
        }
    }
}

#Preview("Gate") {
    OnboardingGateView(userID: UUID())
        .preferredColorScheme(.dark)
}

#Preview("Onboarding") {
    OnboardingView(service: ProfileService(userID: UUID())) {}
        .preferredColorScheme(.dark)
}
