#if DEBUG
import SwiftUI

/// DEBUG-only developer preview section shown at the bottom of ProfileView.
/// Uses subdued, secondary styling so it doesn't overpower the user's real profile data.
struct DebugPreviewSection: View {
    let userID: UUID

    @EnvironmentObject private var library: ExerciseService
    @StateObject private var mock = DebugMockService()
    @StateObject private var photos = ProgressPhotoService()
    @State private var showSummaryPreview = false
    @State private var showMockOnboardingFlow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("开发者与测试工具", "Developer & Testing Tools"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)

            VStack(spacing: 8) {
                // Primary Interactive Wizard
                toolButton(
                    title: L10n.t("🚀 完整新用户开箱模拟流程 (逐步演练)", "🚀 Mock New User Onboarding Journey"),
                    systemImage: "sparkles.rectangle.stack.fill",
                    color: Theme.Colors.ember,
                    isPrimary: true
                ) {
                    showMockOnboardingFlow = true
                }

                // Quick Seed All
                toolButton(
                    title: L10n.t("⚡️ 一键直接注入全套模拟数据", "⚡️ Quick Seed Everything (Direct)"),
                    systemImage: "bolt.fill",
                    color: Theme.Colors.textSecondary
                ) {
                    Task { await mock.seedAll(userID: userID, library: library, photos: photos) }
                }

                toolButton(
                    title: L10n.t("预览训练完成页 + 动画", "Preview Workout Summary & Animation"),
                    systemImage: "trophy.fill",
                    color: Theme.Colors.ember
                ) {
                    showSummaryPreview = true
                }

                toolButton(
                    title: L10n.t("关注模拟用户（填充动态）", "Follow Mock Users (Seed Feed)"),
                    systemImage: "person.2.fill",
                    color: Theme.Colors.textSecondary
                ) {
                    Task { await mock.followMockUsers(userID: userID) }
                }

                toolButton(
                    title: L10n.t("生成历史训练 + PR 纪录", "Generate Workouts & PR Records"),
                    systemImage: "clock.arrow.circlepath",
                    color: Theme.Colors.textSecondary
                ) {
                    Task { await mock.seedMyActivity(userID: userID, library: library) }
                }

                toolButton(
                    title: L10n.t("上传模拟进度照片", "Upload Mock Progress Photos"),
                    systemImage: "photo.stack",
                    color: Theme.Colors.textSecondary
                ) {
                    Task { await mock.seedMyPhotos(using: photos) }
                }
            }

            if mock.isBusy {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(mock.status ?? "…")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .padding(.top, 4)
            } else if let status = mock.status {
                Text(status)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(.top, 4)
            }

            Text(L10n.t("模拟用户与测试数据可通过一键生成或运行 supabase/seed.sql 创建", "Mock users and data can be generated here or seeded via supabase/seed.sql"))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Theme.Colors.textMuted.opacity(0.8))
                .padding(.top, 2)
        }
        .disabled(mock.isBusy)
        .sheet(isPresented: $showSummaryPreview) {
            WorkoutSummaryView(
                summary: DebugMockService.mockSummary(library: library),
                workoutID: UUID(),
                userID: UUID()
            )
        }
        .fullScreenCover(isPresented: $showMockOnboardingFlow) {
            MockOnboardingFlowView()
        }
    }

    private func toolButton(
        title: String,
        systemImage: String,
        color: Color,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isPrimary ? Theme.Colors.emberDeep : color)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 14, weight: isPrimary ? .bold : .medium))
                    .foregroundStyle(isPrimary ? Theme.Colors.emberDeep : Theme.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isPrimary ? Theme.Colors.emberDeep.opacity(0.8) : Theme.Colors.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(isPrimary ? Theme.Colors.ember : Theme.Colors.surfaceSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .strokeBorder(isPrimary ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: isPrimary ? 1.5 : Theme.Border.hairline)
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
