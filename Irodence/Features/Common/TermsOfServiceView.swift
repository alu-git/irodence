import SwiftUI

/// Native in-app Terms of Service (用户服务协议) document.
struct TermsOfServiceView: View {
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
                            Image(systemName: "doc.plaintext.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.Colors.ember)
                            Text(L10n.t("铁证用户服务协议", "Irodence Terms of Service"))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .padding(.top, 4)

                        Text(L10n.t("生效日期：2026年9月1日 · 铁证团队", "Effective Date: Sep 1, 2026 · Irodence Team"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.Colors.textMuted)

                        // Section 1: Acceptance
                        termsCard(
                            number: "01",
                            titleZh: "服务准入与协议接受",
                            titleEn: "Acceptance of Terms",
                            contentZh: "欢迎使用铁证（Irodence）。当你注册账号、登录或使用本应用的任何功能，即表示你已充分阅读、理解并无条件同意受本服务条款及相关社区安全规范约束。",
                            contentEn: "Welcome to Irodence. By creating an account or using our training features, you agree to comply with and be bound by these Terms of Service and Community Safety Guidelines."
                        )

                        // Section 2: Authentic Lifting Integrity
                        termsCard(
                            number: "02",
                            titleZh: "铁证公证与真实试举原则",
                            titleEn: "Lifting Authenticity & Proof Integrity",
                            contentZh: "「力量要有铁证」是本社区的基石准则：\n· 严禁上传剪辑伪造、借力冒充、非本人试举或虚报重量的假片。\n· 严禁串通虚假验杠公证。经证实作弊或恶意刷榜者，将被取消上榜资格、清空段位分，并处以封号处置。",
                            contentEn: "'Strength Demands Proof' is our core axiom:\n· You must not upload forged, counterfeit, non-personal, or falsely weighted lift videos.\n· Collusive verification is strictly prohibited. Confirmed cheating results in tier reset and permanent account ban."
                        )

                        // Section 3: Safety & Health Disclaimer
                        termsCard(
                            number: "03",
                            titleZh: "力量训练健康免责声明",
                            titleEn: "Fitness & Safety Disclaimer",
                            contentZh: "大重量力量举（深蹲、卧推、硬拉等）存在客观运动风险：\n· 在进行极限（1RM）或高负荷试举前，请确保身体状况良好并完成充分热身。\n· 强烈建议配备合格保护者（Spotter）或在具备安全限位销（Safety Bars）的深蹲架/卧推架内完成试举。\n· 铁证不对用户在自主训练中的任何身体意外伤害承担法律责任。",
                            contentEn: "Heavy strength lifting carries inherent physical risks:\n· Ensure proper physical readiness and thorough warmup before attempting max-effort 1RM lifts.\n· Always lift with qualified spotters or safety pins inside a certified power cage.\n· Irodence assumes no liability for athletic injuries sustained during independent training."
                        )

                        // Section 4: Community Conduct & Zero Tolerance Policy
                        termsCard(
                            number: "04",
                            titleZh: "社区公约与零容忍安全政策",
                            titleEn: "Community Standards & Zero-Tolerance Policy",
                            contentZh: "铁证对令人反感的内容（Objectionable Content）与骚扰行为实行严格的零容忍政策：\n· 严禁对其他用户的身材、外貌、性别进行评头论足或言语骚扰；\n· 严禁发布色情低俗、仇恨言论、违法违规或商业导流信息；\n· 用户可使用卡片右上角菜单一键「举报」与「拉黑」违规用户。安全团队将在 24 小时内进行人工核实处理，一经查实立即下架违规内容并对违规账号执行永久封禁。",
                            contentEn: "Irodence strictly enforces a zero-tolerance policy for objectionable content and abusive conduct:\n· No body shaming, derogatory remarks, or harassment of any lifter;\n· No explicit, hateful, unlawful, or spam content;\n· Users can instantly report and block any objectionable content or user. Our moderation team reviews reports within 24 hours to purge violations and permanently ban abusive accounts."
                        )

                        // Section 5: Intellectual Property & Updates
                        termsCard(
                            number: "05",
                            titleZh: "知识产权与服务变更",
                            titleEn: "Intellectual Property & Service Updates",
                            contentZh: "你对自主创作上传的试举视频保留著作权，并授予铁证在公证、排行展示所需的合理授权。铁证保留对算法模型（DOTS 调整力臂系数等）及服务内容进行持续升级优化的权利。",
                            contentEn: "You retain ownership of your uploaded workout media, granting Irodence the limited license required for leaderboard and proof display. We reserve the right to refine algorithms and UI features."
                        )
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(L10n.t("服务条款", "Terms of Service"))
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

    private func termsCard(number: String, titleZh: String, titleEn: String, contentZh: String, contentEn: String) -> some View {
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
