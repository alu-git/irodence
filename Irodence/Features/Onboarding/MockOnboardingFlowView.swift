#if DEBUG
import SwiftUI

/// Full-screen interactive mock onboarding & new user journey simulation.
/// Step-by-step wizard where the user clicks "Next" to progress through each stage,
/// watch data populate live, complete a mock workout, and witness the badge flash celebration.
struct MockOnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: ExerciseService
    @StateObject private var debugService = DebugMockService()

    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    @State private var currentStep: Int = 0
    @State private var selectedRoutineIndex: Int = 0
    @State private var simulatedSetsCount: Int = 4
    @State private var isSimulatingWorkout: Bool = false
    @State private var showSparks: Bool = false
    @State private var badgeAppeared: Bool = false
    @State private var isApplyingData: Bool = false

    private let totalSteps = 6

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.surfaceBase
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. Top Step Progress Bar
                    topProgressBar

                    // 2. Step Content
                    ScrollView {
                        VStack(spacing: 20) {
                            switch currentStep {
                            case 0:
                                step1ProfileGenesis
                            case 1:
                                step2RoutineSelection
                            case 2:
                                step3LiveWorkoutSimulation
                            case 3:
                                step4BadgePromotionFlash
                            case 4:
                                step5CommunityAndFeed
                            case 5:
                                step6ReadyAndLaunch
                            default:
                                EmptyView()
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                    }

                    // 3. Bottom Next Bar
                    bottomActionBar
                }
            }
            .navigationTitle(L10n.t("新用户模拟开箱体验", "Mock Onboarding Journey"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("退出", "Exit")) {
                        dismiss()
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Top Progress Bar

    private var topProgressBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? Theme.Colors.ember : Theme.Colors.surfaceSunken)
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }

            HStack {
                Text(stepTitle(currentStep))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.Colors.ember)

                Spacer()

                Text("\(currentStep + 1) / \(totalSteps)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.Colors.surfaceRaised)
        .overlay(
            Rectangle()
                .fill(Theme.Colors.borderHairline)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func stepTitle(_ step: Int) -> String {
        switch step {
        case 0: return L10n.t("第一步 · 建立铁胚档案", "Step 1 · Lifter Profile Genesis")
        case 1: return L10n.t("第二步 · 挑选首套训练图纸", "Step 2 · Select Routine Blueprint")
        case 2: return L10n.t("第三步 · 模拟开练与记录组数", "Step 3 · Live Workout & PR Logging")
        case 3: return L10n.t("第四步 · 完练结算与段位晋升", "Step 4 · Milestone Tier Promotion")
        case 4: return L10n.t("第五步 · 社群见证与战队熔炉", "Step 5 · Verified Proof & Crew Feed")
        case 5: return L10n.t("第六步 · 体验就绪，开启征程", "Step 6 · Complete & Launch")
        default: return ""
        }
    }

    // MARK: - Step 1: Profile Genesis

    private var step1ProfileGenesis: some View {
        VStack(spacing: 22) {
            // Hero Icon
            ZStack {
                Circle()
                    .fill(Theme.Colors.surfaceRaised)
                    .frame(width: 90, height: 90)
                    .overlay(
                        Circle()
                            .strokeBorder(Theme.Colors.borderMetal, lineWidth: 1)
                    )

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.Colors.ember)
            }
            .padding(.top, 10)

            VStack(spacing: 6) {
                Text(L10n.t("欢迎来到 Irodence 铁证", "Welcome to Irodence"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(L10n.t("系统已为你初始化默认铁友档案", "Default lifter profile initialized for simulation"))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Profile Card
            VStack(spacing: 12) {
                profileRow(icon: "person.fill", label: L10n.t("昵称", "Name"), value: "铁友 (Iron Lifter)")
                Divider().background(Theme.Colors.borderHairline)
                profileRow(icon: "figure.arms.open", label: L10n.t("性别", "Sex"), value: L10n.t("男 ♂", "Male ♂"))
                Divider().background(Theme.Colors.borderHairline)
                profileRow(icon: "scalemass.fill", label: L10n.t("体重", "Bodyweight"), value: "75.0 kg")
                Divider().background(Theme.Colors.borderHairline)
                profileRow(icon: "ruler.fill", label: L10n.t("身高", "Height"), value: "175 cm")
                Divider().background(Theme.Colors.borderHairline)
                profileRow(icon: "circle.grid.cross.fill", label: L10n.t("初始段位", "Initial Tier"), value: L10n.t("生铁 (Pig Iron · 0 分)", "Pig Iron (0 DOTS)"))
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

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                Text(L10n.t("点击「下一步」进入训练图纸库挑选动作", "Click Next to pick your first routine blueprint"))
                    .font(.system(size: 13))
            }
            .foregroundStyle(Theme.Colors.textMuted)
        }
    }

    private func profileRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14.5, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }

    // MARK: - Step 2: Routine Selection

    private var step2RoutineSelection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(L10n.t("挑选首套训练图纸", "Select Workout Blueprint"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(L10n.t("从 24 套经典锻造图纸中挑选一套开启模拟", "Choose from 24 classic routines to simulate"))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            // Routine Options
            VStack(spacing: 12) {
                routineCard(
                    index: 0,
                    title: L10n.t("经典推力力量强化 (PPL - Push A)", "Classic Push Power (PPL - Push A)"),
                    subtitle: L10n.t("~55分钟 · 5个动作 · 胸 / 肩 / 三头", "~55m · 5 exercises · Chest / Delts / Triceps"),
                    exercises: ["杠铃卧推 (5×5)", "上斜哑铃卧推 (3×8)", "杠铃推举 (3×8)", "哑铃侧平举 (4×12)", "绳索三头下压 (3×12)"]
                )

                routineCard(
                    index: 1,
                    title: L10n.t("背部与拉力肌群轰炸 (PPL - Pull A)", "Back & Pull Power (PPL - Pull A)"),
                    subtitle: L10n.t("~50分钟 · 5个动作 · 背阔 / 斜方 / 二头", "~50m · 5 exercises · Lats / Traps / Biceps"),
                    exercises: ["传统硬拉 (3×5)", "高位下拉 (4×10)", "杠铃划船 (4×8)", "绳索面拉 (3×15)", "杠铃二头弯举 (3×10)"]
                )

                routineCard(
                    index: 2,
                    title: L10n.t("下肢深蹲与核心淬火 (PPL - Leg A)", "Squat & Lower Body (PPL - Leg A)"),
                    subtitle: L10n.t("~60分钟 · 5个动作 · 股四 / 臀大肌 / 腘绳", "~60m · 5 exercises · Quads / Glutes / Hamstrings"),
                    exercises: ["杠铃后深蹲 (5×5)", "倒蹬机压腿 (3×10)", "罗马尼亚硬拉 (3×8)", "坐姿腿屈伸 (3×12)", "站姿提踵 (4×15)"]
                )
            }
        }
    }

    private func routineCard(index: Int, title: String, subtitle: String, exercises: [String]) -> some View {
        let isSelected = selectedRoutineIndex == index

        return Button {
            selectedRoutineIndex = index
            ForgeHaptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isSelected ? Theme.Colors.ember : Theme.Colors.textPrimary)

                        Text(subtitle)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(isSelected ? Theme.Colors.ember : Theme.Colors.textMuted)
                }

                Divider().background(Theme.Colors.borderHairline)

                // Exercise Pills
                WrappingHStack(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(exercises, id: \.self) { ex in
                        Text(ex)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(Theme.Colors.surfaceSunken, in: Capsule())
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.Colors.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(isSelected ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: isSelected ? 1.5 : Theme.Border.hairline)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Live Workout Simulation

    private var step3LiveWorkoutSimulation: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(L10n.t("实时训练与组数记录", "Live Workout & Set Logging"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(L10n.t("模拟实时完成训练组并冲击个人新纪录 (PR)", "Simulating completed working sets and striking a new PR"))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            // Live HUD Bar
            HStack(spacing: 12) {
                hudStat(label: L10n.t("训练时长", "Duration"), value: "00:52:14")
                Divider().frame(height: 24).background(Theme.Colors.borderHairline)
                hudStat(label: L10n.t("总容量", "Volume"), value: "8,640 kg")
                Divider().frame(height: 24).background(Theme.Colors.borderHairline)
                hudStat(label: L10n.t("完成组数", "Sets"), value: "14 / 14")
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(Theme.Colors.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
            )

            // Logged Sets Feed
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.t("杠铃卧推 · 组数记录", "Barbell Bench Press · Sets"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Text(L10n.t("已完成 4 组", "4 Sets Done"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Colors.ember)
                }

                VStack(spacing: 8) {
                    setRow(setNum: 1, type: L10n.t("热身", "Warmup"), weight: "60.0 kg", reps: "8 次", isPR: false)
                    setRow(setNum: 2, type: L10n.t("正式", "Working"), weight: "80.0 kg", reps: "5 次", isPR: false)
                    setRow(setNum: 3, type: L10n.t("正式", "Working"), weight: "90.0 kg", reps: "3 次", isPR: false)
                    setRow(setNum: 4, type: L10n.t("冲击", "Heavy"), weight: "100.0 kg", reps: "1 次", isPR: true)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.Colors.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
            )

            // PR Callout Banner
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.Colors.ember)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("💥 突破个人历史最高纪录！", "💥 New Personal Record!"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(L10n.t("杠铃卧推 1RM 达到 100.0 kg，即将触发段位晋升", "Bench Press est. 1RM hit 100 kg — Tier promotion incoming"))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.Colors.ember.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(Theme.Colors.ember.opacity(0.4), lineWidth: 1)
            )
        }
    }

    private func hudStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Colors.textMuted)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.Colors.ember)
        }
        .frame(maxWidth: .infinity)
    }

    private func setRow(setNum: Int, type: String, weight: String, reps: String, isPR: Bool) -> some View {
        HStack {
            Text("\(setNum)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.Colors.textMuted)
                .frame(width: 20)

            Text(type)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isPR ? Theme.Colors.emberDeep : Theme.Colors.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isPR ? Theme.Colors.ember : Theme.Colors.surfaceSunken, in: Capsule())

            Spacer()

            Text(weight)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("×")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.textMuted)

            Text(reps)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.Colors.textPrimary)

            if isPR {
                Text(L10n.t("PR", "PR"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Colors.emberDeep)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Theme.Colors.ember, in: Capsule())
            }

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.ember)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                .fill(isPR ? Theme.Colors.surfaceSunken : Color.clear)
        )
    }

    // MARK: - Step 4: Badges Flash & Milestone Celebration

    private var step4BadgePromotionFlash: some View {
        VStack(spacing: 24) {
            ZStack {
                // Sparks
                TierUpSparksView(isTriggered: true)
                    .frame(height: 240)

                // Large Glowing 210pt Badge with Radial Aura
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    StrengthTier.refinedSteel.color.opacity(0.45),
                                    StrengthTier.refinedSteel.color.opacity(0.12),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)

                    Image(StrengthTier.refinedSteel.assetImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 190, height: 190)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(StrengthTier.refinedSteel.color.opacity(0.8), lineWidth: 3)
                        )
                        .shadow(color: StrengthTier.refinedSteel.color.opacity(0.55), radius: 32, y: 8)
                }
                .metallicSheen(trigger: true, duration: 0.9, delay: 0.2)
            }
            .frame(height: 220)

            VStack(spacing: 6) {
                Text(L10n.t("🔥 TIER PROMOTION · 淬火晋升", "🔥 TIER PROMOTION · LEVEL UP"))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.Colors.ember)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Theme.Colors.surfaceRaised, in: Capsule())

                Text(L10n.t("晋升至：精钢 (Refined Steel)", "Promoted to: Refined Steel"))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(L10n.t("综合力量分 DOTS 跃升至 341 分 · 解锁 3 项勋章", "Total DOTS Score reached 341 · 3 Badges Unlocked"))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            // Unlocked Badges Row
            HStack(spacing: 12) {
                miniBadgeCard(title: L10n.t("破晓新力", "First PR"), desc: L10n.t("首次突破PR", "Hit 1st PR"), icon: "trophy.fill")
                miniBadgeCard(title: L10n.t("万钧重锤", "10-Ton Hammer"), desc: L10n.t("单次超8吨", "8.6T Volume"), icon: "hammer.fill")
                miniBadgeCard(title: L10n.t("精钢之躯", "Refined Steel"), desc: L10n.t("段位晋升", "Tier Up"), icon: "shield.lefthalf.filled")
            }
        }
        .onAppear {
            ForgeHaptics.strike()
        }
    }

    private func miniBadgeCard(title: String, desc: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.Colors.ember)
                .frame(width: 44, height: 44)
                .background(Theme.Colors.surfaceSunken, in: Circle())

            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(desc)
                .font(.system(size: 11))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    // MARK: - Step 5: Community & Feed

    private var step5CommunityAndFeed: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(L10n.t("全域数据沉淀与社群见证", "Community Proof & Crew Feed"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(L10n.t("完成的训练已自动生成加密铁证并同步至战队熔炉", "Workout synced to cryptographically-verified proof feed"))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            // Proof Feed Card Preview
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    AvatarView(name: "铁友", size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("铁友 (Iron Lifter)")
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(L10n.t("刚刚 · 经典推力力量强化", "Just now · Classic Push Power"))
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    Spacer()
                    Label(L10n.t("已验证", "Verified"), systemImage: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.Colors.ember)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.surfaceSunken, in: Capsule())
                }

                Divider().background(Theme.Colors.borderHairline)

                Text(L10n.t("🔥 卧推突破 100kg！顺利晋升精钢段位，感谢战队铁友打气！", "🔥 Hit 100kg Bench PR! Successfully promoted to Refined Steel!"))
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.Colors.textPrimary)

                HStack(spacing: 16) {
                    Label("8,640 kg", systemImage: "scalemass.fill")
                    Label("52 min", systemImage: "clock.fill")
                    Label("100 kg PR", systemImage: "trophy.fill")
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.Colors.ember)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.Colors.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
            )

            // Crew Card Preview
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.ember.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.Colors.ember)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("已加入战队：深蹲不打烊", "Joined Crew: Squat Never Sleeps"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(L10n.t("本次训练已为战队注入 +15 °C 熔炉热度", "Contributed +15 °C heat to the team furnace"))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.Colors.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
            )
        }
    }

    // MARK: - Step 6: Ready & Launch

    private var step6ReadyAndLaunch: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.surfaceRaised)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .strokeBorder(Theme.Colors.ember, lineWidth: 2)
                    )

                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)
            }
            .padding(.top, 10)

            VStack(spacing: 6) {
                Text(L10n.t("模拟体验就绪 · 开启真实锻造", "Simulation Complete · Ready to Forge"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(L10n.t("全套模拟数据（16次训练纪录 + 4大核心PR + 战队动态）已准备完毕", "Complete mock dataset (16 workouts + 4 core PRs + feed) ready"))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Checklist
            VStack(spacing: 12) {
                checkRow(title: L10n.t("个人铁胚档案已就绪 (精钢 341 分)", "Profile Ready (Refined Steel · 341 DOTS)"))
                checkRow(title: L10n.t("4 大核心项历史纪录已生成 (深蹲/卧推/硬拉/推举)", "4 Core PR Records Generated"))
                checkRow(title: L10n.t("24 套经典锻造图纸库已就绪", "24 Classic Blueprint Routines Unlocked"))
                checkRow(title: L10n.t("加密见证动态流与熔炉战队已连通", "Verified Proof Feed & Crew Connected"))
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

            // Replay Button
            Button {
                withAnimation {
                    currentStep = 0
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text(L10n.t("重新体验一遍完整开箱流程", "Replay Full Simulation"))
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.textMuted)
            }
            .padding(.top, 4)
        }
    }

    private func checkRow(title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.ember)
            Text(title)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation {
                        currentStep -= 1
                    }
                    ForgeHaptics.selection()
                } label: {
                    Text(L10n.t("上一步", "Back"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                }
                .buttonStyle(.plain)
            }

            Button {
                advanceStep()
            } label: {
                HStack {
                    Text(nextButtonTitle)
                        .font(.system(size: 16, weight: .bold))
                    Image(systemName: currentStep == totalSteps - 1 ? "arrow.right.circle.fill" : "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Theme.Colors.emberDeep)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Theme.Colors.ember.opacity(0.92), Theme.Colors.ember],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.control)
                )
                .shadow(color: Theme.Colors.ember.opacity(0.35), radius: 10, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Theme.Colors.surfaceRaised)
        .overlay(
            Rectangle()
                .fill(Theme.Colors.borderHairline)
                .frame(height: 1),
            alignment: .top
        )
    }

    private var nextButtonTitle: String {
        switch currentStep {
        case 0: return L10n.t("确认档案 · 下一步", "Confirm Profile · Next")
        case 1: return L10n.t("装载图纸 · 开启训练", "Load Blueprint · Start")
        case 2: return L10n.t("完成训练 · 完练结算", "Finish Workout · Complete")
        case 3: return L10n.t("佩戴勋章 · 进入社群", "Claim Badge · View Feed")
        case 4: return L10n.t("查看完整沉淀成果", "View Ready Summary")
        case 5: return L10n.t("🚀 立即进入应用探索", "🚀 Enter App & Explore")
        default: return L10n.t("下一步", "Next")
        }
    }

    private func advanceStep() {
        ForgeHaptics.selection()
        if currentStep < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.35)) {
                currentStep += 1
            }
        } else {
            // Apply mock dataset
            Task {
                if let userID = SupabaseService.client.auth.currentUser?.id {
                    await debugService.seedMyActivity(userID: userID, library: library)
                }
                dismiss()
            }
        }
    }
}

// MARK: - Wrapping HStack for exercise pills
private struct WrappingHStack: Layout {
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                height += rowHeight + verticalSpacing
                rowHeight = 0
            }
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
#endif
