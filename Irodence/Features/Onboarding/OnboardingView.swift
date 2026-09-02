import SwiftUI

/// Gate between sign-in and the main app. Loads the profile once and routes
/// brand-new accounts (DB-trigger default profile, no sex set) through
/// OnboardingView before revealing the tabs.
struct OnboardingGateView: View {
    @StateObject private var service: ProfileService
    @State private var phase: Phase
    private let userID: UUID

    private enum Phase {
        case loading, onboarding, main
    }

    init(userID: UUID) {
        self.userID = userID
        let initialService = ProfileService(userID: userID)
        _service = StateObject(wrappedValue: initialService)
        _phase = State(initialValue: initialService.needsOnboarding ? .onboarding : .main)
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ForgeLoadingScreen(message: L10n.t("锻造档案中…", "Loading profile…"))
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
            if service.needsOnboarding && phase != .onboarding {
                withAnimation { phase = .onboarding }
            }
        }
    }
}

/// Streamlined 3-step Profile Setup for fast initial account onboarding:
/// Step 1: 昵称 (Nickname)
/// Step 2: 生理性别 (Gender / Biological Sex: ♂ Male, ♀ Female, ⚪ Other/Prefer not to say)
/// Step 3: 身体指标 (Weight / Height / Age)
struct OnboardingView: View {
    @ObservedObject var service: ProfileService
    let onFinished: () -> Void

    @State private var step: Step = .name
    @State private var name: String
    @State private var sex: Sex?
    @State private var bodyweightText = ""
    @State private var heightText = ""
    @State private var ageText = ""
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    enum Step: Int, CaseIterable {
        case name = 0
        case sex = 1
        case metrics = 2

        var stepNumber: Int { rawValue + 1 }
        var totalSteps: Int { Step.allCases.count }
    }

    private enum Field {
        case name, bodyweight, height, age
    }

    init(service: ProfileService, onFinished: @escaping () -> Void) {
        self.service = service
        self.onFinished = onFinished
        _name = State(initialValue: service.profile?.displayName ?? "")
        _sex = State(initialValue: service.profile?.sex)
        _bodyweightText = State(initialValue: service.profile?.bodyweightKg.map { String(format: "%.1f", $0) } ?? "75")
        _heightText = State(initialValue: service.profile?.heightCm.map { String(format: "%.0f", $0) } ?? "175")
        _ageText = State(initialValue: service.profile?.ageYears.map { String($0) } ?? "26")
    }

    var body: some View {
        ZStack {
            Theme.Colors.surfaceBase.ignoresSafeArea()

            VStack(spacing: 0) {
                topNavigationBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        stepHeaderView
                            .padding(.top, 12)

                        stepContentView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                            .id(step)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }

                Spacer(minLength: 0)

                bottomActionBar
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                    .background(Theme.Colors.surfaceBase)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: step)
        .onAppear {
            if step == .name {
                focusedField = .name
            }
        }
    }

    // MARK: - Navigation Bar

    private var topNavigationBar: some View {
        HStack(spacing: 16) {
            if step != .name {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 38, height: 38)
                        .background(Theme.Colors.surfaceRaised, in: Circle())
                }
            } else {
                Color.clear.frame(width: 38, height: 38)
            }

            // 3 Clean Step Progress Capsules
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Theme.Colors.ember : Theme.Colors.surfaceRaised)
                        .frame(height: 5)
                        .animation(.spring(duration: 0.25), value: step)
                }
            }

            Button(L10n.t("跳过", "Skip")) {
                skipStep()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.Colors.textMuted)
            .frame(width: 38, alignment: .trailing)
        }
    }

    // MARK: - Step Header

    private var stepHeaderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.t("步骤 \(step.stepNumber)/\(step.totalSteps)", "Step \(step.stepNumber) of \(step.totalSteps)"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.ember.opacity(0.16), in: Capsule())
                Spacer()
            }

            switch step {
            case .name:
                Text(L10n.t("怎么称呼你？", "What's your name?"))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(L10n.t("在铁证社区、动态与锻造榜上展示给铁友的名字", "Your nickname on the feed, crew, and leaderboards"))
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)

            case .sex:
                Text(L10n.t("你的生理性别", "Select Gender"))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(L10n.t("国际 DOTS 公式依据生理特征计算公平的相对力量分", "Used by DOTS formula for fair relative strength scoring"))
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)

            case .metrics:
                Text(L10n.t("身体基础数据", "Body Metrics"))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(L10n.t("体重用于计算力量分与段位，之后可在「我的」随时修改", "Calibrates your baseline strength tier; editable anytime in Profile"))
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContentView: some View {
        switch step {
        case .name:
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("铁友昵称", "Nickname"))
                    .font(Theme.Typography.label.bold())
                    .foregroundStyle(Theme.Colors.textSecondary)

                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Colors.ember)

                    TextField(L10n.t("输入你的昵称 (如：深蹲狂魔)", "Enter nickname (e.g. IronLifter)"), text: $name)
                        .font(.system(size: 17, weight: .medium))
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit(advance)
                }
                .padding(16)
                .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(focusedField == .name ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: 1.2)
                )
            }
            .padding(.top, 8)

        case .sex:
            VStack(spacing: 12) {
                genderSelectionCard(
                    option: .male,
                    symbol: "♂",
                    labelZh: "男",
                    labelEn: "Male",
                    desc: L10n.t("采用男子 DOTS 标准力量系数", "Uses standard Male DOTS coefficients")
                )

                genderSelectionCard(
                    option: .female,
                    symbol: "♀",
                    labelZh: "女",
                    labelEn: "Female",
                    desc: L10n.t("采用女子 DOTS 标准力量系数", "Uses standard Female DOTS coefficients")
                )

                genderSelectionCard(
                    option: .other,
                    symbol: "⚪",
                    labelZh: "其他 / 保密",
                    labelEn: "Other / Prefer not to say",
                    desc: L10n.t("采用通用平衡力量系数", "Uses balanced general strength coefficients")
                )
            }
            .padding(.top, 8)

        case .metrics:
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    metricInputField(
                        title: L10n.t("体重 (kg) *", "Weight (kg) *"),
                        placeholder: "75.0",
                        text: $bodyweightText,
                        keyboard: .decimalPad,
                        field: .bodyweight,
                        isHighlighted: true
                    )

                    metricInputField(
                        title: L10n.t("身高 (cm)", "Height (cm)"),
                        placeholder: "175",
                        text: $heightText,
                        keyboard: .numberPad,
                        field: .height,
                        isHighlighted: false
                    )
                }

                metricInputField(
                    title: L10n.t("年龄 (岁)", "Age (years)"),
                    placeholder: "26",
                    text: $ageText,
                    keyboard: .numberPad,
                    field: .age,
                    isHighlighted: false
                )
            }
            .padding(.top, 8)
        }
    }

    private func genderSelectionCard(option: Sex, symbol: String, labelZh: String, labelEn: String, desc: String) -> some View {
        let isSelected = sex == option

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                sex = option
            }
        } label: {
            HStack(spacing: 16) {
                Text(symbol)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(isSelected ? Theme.Colors.ember : Theme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Theme.Colors.ember.opacity(0.18) : Theme.Colors.surfaceBase, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t(labelZh, labelEn))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)

                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Theme.Colors.ember : Theme.Colors.borderMetal)
            }
            .padding(16)
            .background(
                isSelected ? Theme.Colors.surfaceRaised : Theme.Colors.surfaceBase,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: isSelected ? 1.8 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func metricInputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        field: Field,
        isHighlighted: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.Typography.label.bold())
                .foregroundStyle(isHighlighted ? Theme.Colors.ember : Theme.Colors.textSecondary)

            TextField(placeholder, text: text)
                .font(.system(size: 18, weight: .bold))
                .padding(14)
                .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(focusedField == field ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: 1.2)
                )
                .keyboardType(keyboard)
                .focused($focusedField, equals: field)
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            Button(action: advance) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(Theme.Colors.emberDeep)
                    } else {
                        Text(step == .metrics ? L10n.t("进入铁证，开启锻造", "Enter Irodence & Start Forging") : L10n.t("下一步", "Next"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.Colors.emberDeep)

                        Image(systemName: step == .metrics ? "checkmark" : "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.Colors.emberDeep)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canAdvance ? Theme.Colors.ember : Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance || isSaving)

            Button(L10n.t("稍后设置 (跳过)", "Set Up Later (Skip)")) {
                skipStep()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.Colors.textMuted)
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .name:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .sex:
            return sex != nil
        case .metrics:
            guard let bw = parsedBodyweight else { return false }
            return bw > 20 && bw < 400
        }
    }

    // MARK: - Navigation Logic

    private func advance() {
        guard canAdvance else { return }
        focusedField = nil

        switch step {
        case .name:
            step = .sex
        case .sex:
            step = .metrics
            focusedField = .bodyweight
        case .metrics:
            finishAndEnterApp()
        }
    }

    private func goBack() {
        focusedField = nil
        switch step {
        case .name: break
        case .sex:
            step = .name
            focusedField = .name
        case .metrics:
            step = .sex
        }
    }

    private func skipStep() {
        focusedField = nil
        switch step {
        case .name:
            name = name.isEmpty ? L10n.t("铁友", "Lifter") : name
            step = .sex
        case .sex:
            sex = sex ?? .male
            step = .metrics
            focusedField = .bodyweight
        case .metrics:
            finishAndEnterApp()
        }
    }

    private func finishAndEnterApp() {
        isSaving = true
        focusedField = nil
        Task {
            let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.t("铁友", "Lifter") : name
            let ok = await service.completeOnboarding(
                name: finalName,
                sex: sex ?? .male,
                bodyweightKg: parsedBodyweight ?? 75.0,
                heightCm: parsedHeight,
                ageYears: parsedAge
            )
            isSaving = false
            if ok {
                service.skipOnboarding()
                onFinished()
            } else {
                service.skipOnboarding()
                onFinished()
            }
        }
    }

    private var parsedBodyweight: Double? {
        let t = bodyweightText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return Double(t)
    }

    private var parsedHeight: Double? {
        let t = heightText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return Double(t)
    }

    private var parsedAge: Int? {
        let t = ageText.trimmingCharacters(in: .whitespaces)
        return Int(t)
    }
}
