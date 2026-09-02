import SwiftUI

/// Native in-app Privacy Policy document adhering to RODENCE_SAFETY.md.
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.surfaceBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md + 4) {
                        // Header Badge
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.shield.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.Colors.ember)
                            Text(L10n.t("铁证隐私与安全规范", "Irodence Privacy & Safety Spec"))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .padding(.top, 4)

                        Text(L10n.t("生效日期：2026年9月1日 · 铁证团队", "Effective Date: Sep 1, 2026 · Irodence Team"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.Colors.textMuted)

                        // Section 1: Overview
                        policyCard(
                            number: "01",
                            titleZh: "核心隐私承诺",
                            titleEn: "Core Privacy Commitment",
                            contentZh: "铁证（Irodence）是一个专注于力量举与健力记录的纯粹硬核社区。我们深知身体数据与试举视频的高度私密性，郑重承诺：绝不向任何第三方出售、共享或商业化变现你的个人体征、训练视频与活动档案。",
                            contentEn: "Irodence is a pure strength lifting and verification platform. We treat all biomechanical metrics and video recordings with utmost confidentiality, and will never sell, trade, or commercialize your personal data."
                        )

                        // Section 2: Data Collection
                        policyCard(
                            number: "02",
                            titleZh: "我们收集的数据与用途",
                            titleEn: "Data We Collect & Purpose",
                            contentZh: "· 生理性别、体重、身高与年龄：仅用于国际标准 DOTS 力量分多项式数学折算及 Master 大师年龄公平加权。\n· 训练与组数记录：用于计算你的总容量吨位、疲劳度 RPE 与 1RM 极限预测。\n· 试举视频（UGC）：用于社区同炉验杠与真实性公证，附带 SHA-256 唯一数字指纹防止盗录与篡改。",
                            contentEn: "· Biometrics (Sex, Weight, Height, Age): Strictly used for standard DOTS formula weighting and master age compensation.\n· Workout Logs & Sets: Used to calculate volume tonnage, RPE fatigue curves, and 1RM max estimates.\n· Proof Videos: Used strictly for community lift verification with SHA-256 integrity fingerprints."
                        )

                        // Section 3: Video Privacy & Visibility
                        policyCard(
                            number: "03",
                            titleZh: "视频权限与可见性控制",
                            titleEn: "Video Visibility & Access Controls",
                            contentZh: "你对上传的每条试举视频拥有 100% 的自主掌控权：\n· 「仅熔炉铁友可见」：仅限你加入的私密小队成员验杠查阅。\n· 「全广场公开见证」：进入公共见证广场与全站锻造榜。\n· 随时支持一键删除已有视频，删除后云端存储介质将即刻物理清除。",
                            contentEn: "You have 100% granular control over every uploaded lift video:\n· 'Crew-Only': Restricted strictly to members of your verified furnace team.\n· 'Public Feed': Visible to the global proving ground and leaderboard.\n· Immediate permanent physical purge upon deletion."
                        )

                        // Section 4: Anti-Harassment
                        policyCard(
                            number: "04",
                            titleZh: "女性友好与反骚扰安全防线",
                            titleEn: "Anti-Harassment & Safe Community",
                            contentZh: "针对健身视频容易滋生骚扰的痛点，铁证构建了严格的反骚扰机制：\n· 静默拉黑（Silent Block）：一键拉黑可疑用户，对方不会收到通知，且无法再查看你的任何动态与视频。\n· 违规一键举报：涉嫌骚扰、不当言论或侵犯隐私的举报将在 24 小时内由安全审核团队处理。",
                            contentEn: "We enforce zero-tolerance anti-harassment safeguards:\n· Silent Blocking: Instantly cut off unwanted interactions without notifying the blocked party.\n· 1-Tap Incident Reporting: Swift 24-hour moderation response against misconduct, derogatory comments, or violations."
                        )

                        // Section 5: Account Deletion
                        policyCard(
                            number: "05",
                            titleZh: "一键彻底注销与数据清除",
                            titleEn: "Account Deletion & Data Rights",
                            contentZh: "根据国家个人信息保护法与国际隐私准则，你在「设置 - 注销账号」中可随时发起注销。确认后，云端数据库及对象存储中的所有个人信息、试举视频、证词与历史日志将永久不可逆物理清除。",
                            contentEn: "In accordance with data privacy regulations, you can permanently delete your account at any time via Settings. All database rows, authentication tokens, and cloud video blobs will be irreversibly erased."
                        )
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(L10n.t("隐私政策", "Privacy Policy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("关闭", "Close")) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private func policyCard(number: String, titleZh: String, titleEn: String, contentZh: String, contentEn: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(number)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.Colors.ember)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: 4))

                Text(L10n.t(titleZh, titleEn))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            Text(L10n.t(contentZh, contentEn))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineSpacing(4)
                .padding(.top, 2)
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
}
