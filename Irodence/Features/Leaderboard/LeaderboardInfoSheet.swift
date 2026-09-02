import SwiftUI

/// Explanation sheet describing the rules, scoring models, and certification tiers of 锻造榜.
struct LeaderboardInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.surfaceBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Section 1: 力量分与四大核心动作
                        infoCard(
                            title: L10n.t("四大核心动作 · 力量分", "Big 4 Core Lifts · Strength Score"),
                            icon: "dumbbell.fill",
                            description: L10n.t(
                                "深蹲、卧推、硬拉以及 SBD 总和属于核心力量大项。采用国际标准 DOTS (Dynamic Objective Total Scoring) 系数，根据举起重量、体重及性别进行多项式数学加权，消除体重与性别差异，衡量最纯粹的绝对锻造水平。",
                                "Squat, Bench, Deadlift, and SBD Total are the core lifts. Rankings use standard DOTS coefficients weighted by lifted weight, bodyweight, and sex to measure pure strength across all weight classes."
                            )
                        )

                        // Section 2: 全量动作库 · 1RM与相对力量
                        infoCard(
                            title: L10n.t("全量动作库 · 1RM 与 相对力量", "All Exercises · 1RM & Relative Strength"),
                            icon: "list.bullet.rectangle.portrait.fill",
                            description: L10n.t(
                                "除四大项外的所有动作（如引体向上、站姿推举、杠铃划船等）以预估 1RM 重量在同性别、同体重级别内排行。\n\n次要指标展示「相对力量 = 1RM / 体重」（如 1.4×体重），非核心项目严格不计算力量分。",
                                "Non-core exercises (e.g. Pull-Ups, OHP, Barbell Rows) are ranked by estimated 1RM within your weight class and sex.\n\nRelative strength is displayed as 1RM / bodyweight (e.g. 1.4× BW). No Strength Score is computed for non-core lifts."
                            )
                        )

                        // Section 3: 铁证认证与 3 人上榜门禁
                        infoCard(
                            title: L10n.t("铁证认证与上榜门禁", "Certification & 3-Lifter Minimum"),
                            icon: "checkmark.seal.fill",
                            description: L10n.t(
                                "锻造榜只展示真实、可验证的力量铁证。仅有上传试举视频、经同炉或社区铁友验杠认证通过的 PR 记录才可进入排行榜。\n\n若某个动作认证人数少于 3 人，榜单将保持「虚位以待」，期待你上传铁证成为首位上榜者！",
                                "Only video-verified lifts witnessed by the community appear on the leaderboard.\n\nBoards with fewer than 3 verified lifters remain unclaimed—submit proof to become the first ranked lifter!"
                            )
                        )

                        // Section 4: 六大锻造段位
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "flame.fill")
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundStyle(Theme.Colors.ember)
                                Text(L10n.t("六大锻造段位", "The 6 Forged Tiers"))
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }

                            Text(L10n.t("力量分映射为六种淬火金属材质，体现段位与造诣：", "Strength scores map onto 6 forged metal tiers reflecting mastery:"))
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)

                            VStack(spacing: Theme.Spacing.xs) {
                                ForEach(StrengthTier.allCases, id: \.self) { tier in
                                    HStack {
                                        Label(tier.displayName, systemImage: tier.systemImage)
                                            .font(Theme.Typography.label)
                                            .foregroundStyle(tier.color)
                                        Spacer()
                                        Text(tierDescription(for: tier))
                                            .font(Theme.Typography.caption)
                                            .foregroundStyle(Theme.Colors.textMuted)
                                    }
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, Theme.Spacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                                            .fill(Theme.Colors.surfaceSunken)
                                    )
                                }
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .fill(Theme.Colors.surfaceRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .strokeBorder(Theme.Colors.borderHairline, lineWidth: Theme.Border.hairline)
                        )
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle(L10n.t("锻造榜规则", "Leaderboard Rules"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("关闭", "Close")) {
                        dismiss()
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private func infoCard(title: String, icon: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(Theme.Colors.ember)
                Text(title)
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            Divider()
                .background(Theme.Colors.borderHairline)
                .padding(.vertical, 2)

            Text(description)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderHairline, lineWidth: Theme.Border.hairline)
        )
    }

    private func tierDescription(for tier: StrengthTier) -> String {
        switch tier {
        case .pigIron: return L10n.t("初入铁砧 · 新手入门", "Pig Iron · Novice")
        case .wroughtIron: return L10n.t("烈火淬炼 · 进阶稳步", "Wrought Iron · Early Intermediate")
        case .castSteel: return L10n.t("扎实坚韧 · 突破百斤", "Cast Steel · Intermediate")
        case .refinedSteel: return L10n.t("百炼成钢 · 中流砥柱", "Refined Steel · Advanced")
        case .reforged: return L10n.t("重构极限 · 竞技顶尖", "Reforged · Elite Competitive")
        case .hundredFold: return L10n.t("登峰造极 · 镇炉之宝", "Masterwork · World Class")
        }
    }
}
