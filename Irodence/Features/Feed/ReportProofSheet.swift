import SwiftUI

/// Modal sheet for reporting a proof or lifter per IRODENCE_SAFETY.md.
/// Includes harassment prioritization and optional one-tap block.
struct ReportProofSheet: View {
    let reporterID: UUID
    let targetProofID: UUID?
    let targetUserID: UUID
    let targetUserName: String
    let onReportSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: ReportReason = .harassment
    @State private var details: String = ""
    @State private var alsoBlockUser: Bool = true
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String? = nil

    private let reportService = ReportService.shared
    private let blockService = BlockService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.surfaceBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Header Guidance
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundStyle(Theme.Colors.ember)
                                Text(L10n.t("铁证社区安全与风控", "Irodence Safety & Moderation"))
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }

                            Text(L10n.t("我们对性骚扰、恶意攻击与违规行为采取零容忍态度。骚扰类举报将进入 24 小时人工审核通道。", "Zero-tolerance for harassment, abuse, or unsafe content. Harassment reports are prioritized for human review within 24h."))
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
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

                        // Reason Picker
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(L10n.t("举报原因", "Reason for Report"))
                                .font(Theme.Typography.cardTitle)
                                .foregroundStyle(Theme.Colors.textPrimary)

                            ForEach(ReportReason.allCases) { reason in
                                Button {
                                    selectedReason = reason
                                } label: {
                                    HStack(spacing: Theme.Spacing.sm) {
                                        Image(systemName: selectedReason == reason ? "largecircle.fill.circle" : "circle")
                                            .font(Theme.Typography.body)
                                            .foregroundStyle(selectedReason == reason ? Theme.Colors.ember : Theme.Colors.textMuted)

                                        Text(reason.displayName)
                                            .font(Theme.Typography.body)
                                            .foregroundStyle(selectedReason == reason ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                                            .multilineTextAlignment(.leading)

                                        Spacer()
                                    }
                                    .padding(Theme.Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                                            .fill(selectedReason == reason ? Theme.Colors.surfaceRaised : Theme.Colors.surfaceSunken)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                                            .strokeBorder(selectedReason == reason ? Theme.Colors.ember.opacity(0.6) : Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Additional Notes
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(L10n.t("补充说明 (可选)", "Additional Details (Optional)"))
                                .font(Theme.Typography.cardTitle)
                                .foregroundStyle(Theme.Colors.textPrimary)

                            TextField(L10n.t("描述具体发生的情况以协助人工核查…", "Describe what occurred to assist our human review team…"), text: $details, axis: .vertical)
                                .lineLimit(3...5)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .padding(Theme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                                        .fill(Theme.Colors.surfaceSunken)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                                        .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                                )
                        }

                        // Block Option
                        Toggle(isOn: $alsoBlockUser) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("同时静默拉黑该用户", "Also silently block this user"))
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text(L10n.t("对方将无法看到你的动态与证词，且无法向你发起熔炉邀请", "Hides your content from them and silently prevents crew invites"))
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }
                        }
                        .tint(Theme.Colors.ember)
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .fill(Theme.Colors.surfaceRaised)
                        )

                        if let error = errorMessage {
                            Text(error)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.danger)
                        }

                        // Submit Button
                        Button {
                            submitReport()
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(Theme.Colors.textOnEmber)
                                } else {
                                    Image(systemName: "checkmark.shield.fill")
                                    Text(L10n.t("提交举报", "Submit Report"))
                                }
                            }
                            .font(Theme.Typography.cardTitle)
                            .foregroundStyle(Theme.Colors.textOnEmber)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.control)
                                    .fill(Theme.Colors.ember)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isSubmitting)
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle(L10n.t("举报与风控", "Report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("取消", "Cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .alert(L10n.t("举报已受理", "Report Received"), isPresented: $showSuccess) {
                Button(L10n.t("确定", "OK")) {
                    dismiss()
                    onReportSubmitted()
                }
            } message: {
                Text(L10n.t("感谢你对社区安全的守护。人工审核团队将依法依规尽快复核处置。", "Thank you for keeping the forge safe. Our moderation team will review this promptly."))
            }
        }
    }

    private func submitReport() {
        isSubmitting = true
        Task {
            do {
                if alsoBlockUser {
                    await blockService.blockUser(targetID: targetUserID, blockerID: reporterID)
                }

                try await reportService.submitReport(
                    reporterID: reporterID,
                    targetProofID: targetProofID,
                    targetUserID: targetUserID,
                    reason: selectedReason,
                    details: details.isEmpty ? nil : details
                )

                isSubmitting = false
                showSuccess = true
            } catch {
                isSubmitting = false
                errorMessage = L10n.t("提交失败，请稍后重试", "Failed to submit, please try again")
            }
        }
    }
}
