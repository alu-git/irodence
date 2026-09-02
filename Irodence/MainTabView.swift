import SwiftUI

/// Main tab shell for 铁证 / Irodence.
/// Tabs: 训练 (Workout), 见证 (Feed), 熔炉 (Crew), 动作库 (Library), 我的 (Profile).
struct MainTabView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var library = ExerciseService()
    @StateObject private var workoutManager: WorkoutManager
    private let userID: UUID

    @AppStorage("hasCompletedInAppTour") private var hasCompletedInAppTour = false
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue
    @State private var selectedTab: Int = 0
    @State private var showInAppTour: Bool = false
    @State private var tourStepIndex: Int = 0

    init(userID: UUID) {
        self.userID = userID
        _workoutManager = StateObject(wrappedValue: WorkoutManager(userID: userID))
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ProofFeedView(userID: userID)
                    .tabItem { Label(L10n.t("见证", "Feed"), systemImage: "hammer.fill") }
                    .tag(0)

                WorkoutTabView()
                    .tabItem { Label(L10n.t("训练", "Workout"), systemImage: "dumbbell.fill") }
                    .tag(1)
                    .environmentObject(workoutManager)
                    .environmentObject(library)

                CrewView(userID: userID)
                    .tabItem { Label(L10n.t("熔炉", "Crew"), systemImage: "flame.fill") }
                    .tag(2)

                ExerciseLibraryView()
                    .tabItem { Label(L10n.t("动作库", "Library"), systemImage: "list.bullet.rectangle") }
                    .tag(3)
                    .environmentObject(library)

                ProfileView(userID: userID)
                    .tabItem { Label(L10n.t("我的", "Profile"), systemImage: "person.fill") }
                    .tag(4)
                    .environmentObject(library)
                    .environmentObject(workoutManager)
            }
            .tint(Theme.Colors.ember)
            .id(language)

            // Interactive Spotlight In-App Tour Overlay
            if showInAppTour {
                InAppTourOverlay(
                    currentStepIndex: $tourStepIndex,
                    isPresented: $showInAppTour,
                    onTabChange: { newTab in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = newTab
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .task {
            await library.loadIfNeeded()
            if !hasCompletedInAppTour {
                // Short delay so views mount before showing the interactive tour
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.easeIn(duration: 0.3)) {
                    showInAppTour = true
                    selectedTab = 2 // Start by highlighting 熔炉 (Crew)
                }
            }
        }
    }
}

// MARK: - In-App Spotlight Tour Overlay

struct InAppTourOverlay: View {
    @Binding var currentStepIndex: Int
    @Binding var isPresented: Bool
    let onTabChange: (Int) -> Void

    struct TourStep {
        let tabIndex: Int
        let icon: String
        let titleZh: String
        let titleEn: String
        let descZh: String
        let descEn: String
        let highlightTabNameZh: String
        let highlightTabNameEn: String
    }

    private let steps: [TourStep] = [
        TourStep(
            tabIndex: 2,
            icon: "flame.fill",
            titleZh: "什么是「熔炉」？",
            titleEn: "What is The Crew?",
            descZh: "「熔炉 (Crew)」是你的铁友力量战队社群。在这里你可以加入或创建战队，与铁友一起备赛打卡、比拼全队总吨位与活跃度！",
            descEn: "The Crew is your lifter brotherhood. Create or join training crews, compete on volume tonnage, and motivate each other.",
            highlightTabNameZh: "当前高亮：熔炉 Tab",
            highlightTabNameEn: "Highlighting: Crew Tab"
        ),
        TourStep(
            tabIndex: 0,
            icon: "hammer.fill",
            titleZh: "什么是「见证」？",
            titleEn: "What is Proof Feed?",
            descZh: "「见证」是真实力量公证广场。查看铁友附带 SHA-256 视频防伪指纹的 PR 记录，支持视频点赞与公证认证，拒绝口嗨假片！",
            descEn: "The verified community square. Inspect lift videos with cryptographic SHA-256 integrity checks and certified seals.",
            highlightTabNameZh: "当前高亮：见证 Tab",
            highlightTabNameEn: "Highlighting: Feed Tab"
        ),
        TourStep(
            tabIndex: 1,
            icon: "dumbbell.fill",
            titleZh: "什么是「训练」？",
            titleEn: "What is Workout?",
            descZh: "「训练」是你的日常主阵地。支持一键开练、套用推拉腿经典模板、记录每组重量、RPE 疲劳度与智能休息倒计时。",
            descEn: "Your workout console. Start sessions with built-in PPL routines, track RPE ratings, drop sets, and rest timers.",
            highlightTabNameZh: "当前高亮：训练 Tab",
            highlightTabNameEn: "Highlighting: Workout Tab"
        ),
        TourStep(
            tabIndex: 3,
            icon: "list.bullet.rectangle",
            titleZh: "什么是「动作库」？",
            titleEn: "What is Exercise Library?",
            descZh: "「动作库」是你的随身解剖宝典。内置 100+ 复合与孤立动作的肌肉激活热力图、双语动作要领与视频演示，助你科学平衡全身肌群。",
            descEn: "Your anatomical exercise handbook. Features dual-side muscle heatmaps, bilingual cues, and tutorial video guides.",
            highlightTabNameZh: "当前高亮：动作库 Tab",
            highlightTabNameEn: "Highlighting: Library Tab"
        ),
        TourStep(
            tabIndex: 4,
            icon: "person.fill",
            titleZh: "什么是「我的」与段位？",
            titleEn: "What is Profile & Forge Tiers?",
            descZh: "「我的」是你的专属锻造殿堂。基于国际 DOTS 算法实时计算你的力量分，点亮生铁到极意的 6 大锻造段位、1RM 估算曲线与身材相册。",
            descEn: "Your forge sanctuary. Tracks DOTS scores, 6 Forge Metal Tiers (Raw Iron to Mastery), 1RM curves, and progress photos.",
            highlightTabNameZh: "当前高亮：我的 Tab",
            highlightTabNameEn: "Highlighting: Profile Tab"
        ),
    ]

    var body: some View {
        let currentStep = steps[min(max(currentStepIndex, 0), steps.count - 1)]

        ZStack {
            // Darkened Dim Backdrop
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture {
                    advance()
                }

            VStack(spacing: 0) {
                // Top header bar with skip button
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.Colors.ember)
                        Text(L10n.t("应用导览与功能速查", "App Tour & Concepts"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    Button(L10n.t("跳过导览", "Skip Tour")) {
                        closeTour()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1), in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                Spacer()

                // Floating Spotlight Card
                VStack(spacing: 16) {
                    HStack {
                        // Icon Badge
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.ember.opacity(0.2))
                                .frame(width: 48, height: 48)
                            Image(systemName: currentStep.icon)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Theme.Colors.ember)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.t("第 \(currentStepIndex + 1)/\(steps.count) 站 · \(currentStep.highlightTabNameZh)", "Step \(currentStepIndex + 1)/\(steps.count) · \(currentStep.highlightTabNameEn)"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.Colors.ember)

                            Text(L10n.t(currentStep.titleZh, currentStep.titleEn))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        Spacer()
                    }

                    Text(L10n.t(currentStep.descZh, currentStep.descEn))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    // Step Dots Indicator & Next Button
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            ForEach(0..<steps.count, id: \.self) { idx in
                                Circle()
                                    .fill(idx == currentStepIndex ? Theme.Colors.ember : Color.white.opacity(0.2))
                                    .frame(width: idx == currentStepIndex ? 8 : 6, height: idx == currentStepIndex ? 8 : 6)
                                    .animation(.spring(duration: 0.2), value: currentStepIndex)
                            }
                        }

                        Spacer()

                        Button(action: advance) {
                            HStack(spacing: 6) {
                                Text(currentStepIndex == steps.count - 1 ? L10n.t("完成，开启锻造！", "Start Forging!") : L10n.t("下一站", "Next Tab"))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Theme.Colors.emberDeep)

                                Image(systemName: currentStepIndex == steps.count - 1 ? "checkmark" : "arrow.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.Colors.emberDeep)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Theme.Colors.ember, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.Colors.surfaceRaised)
                        .shadow(color: Color.black.opacity(0.5), radius: 20, y: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Theme.Colors.ember.opacity(0.5), lineWidth: 1.5)
                )
                .padding(.horizontal, 16)

                // Spotlight Pulsing Pointer pointing down to tab bar
                VStack(spacing: 4) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Colors.ember)

                    Text(L10n.t("底部导航已切换至对应功能", "Tab switched below for live view"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .padding(.top, 12)
                .padding(.bottom, 60)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentStepIndex)
    }

    private func advance() {
        if currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
            onTabChange(steps[currentStepIndex].tabIndex)
        } else {
            closeTour()
        }
    }

    private func closeTour() {
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
            UserDefaults.standard.set(true, forKey: "hasCompletedInAppTour")
        }
    }
}

#Preview {
    MainTabView(userID: UUID())
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}
