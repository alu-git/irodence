import SwiftUI

/// Static 1080×1350 (4:5) share card rendered offscreen via ImageRenderer —
/// sized for WeChat Moments and social sharing. Strictly adheres to IRODENCE_DESIGN.md.
struct ShareSummaryCardView: View {
    let summary: WorkoutManager.Summary
    var achievements: [AchievementItem] = []

    /// The session's most significant PR.
    private var topPR: WorkoutManager.PRResult? {
        summary.prs.max {
            ($0.deltaKg ?? 0, $0.estimated1RM) < ($1.deltaKg ?? 0, $1.estimated1RM)
        }
    }

    var body: some View {
        ZStack {
            Theme.Colors.surfaceBase

            VStack(spacing: 0) {
                // Header Branding
                HStack {
                    Text("铁证 IRODENCE")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .tracking(2)

                    Spacer()

                    Text(Date(), format: .dateTime.year().month().day())
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                Spacer()

                // Hero Content
                if let pr = topPR {
                    VStack(spacing: 10) {
                        Text(L10n.t("百炼成钢又近一步", "One step closer to masterwork"))
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)

                        if let dots = summary.dotsScore {
                            Text(String(format: "%.1f", dots))
                                .font(.system(size: 64, weight: .bold, design: .default).monospacedDigit())
                                .foregroundStyle(Theme.Colors.ember)

                            Text(scoreScopeText)
                                .font(Theme.Typography.label)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }

                        // PR Card
                        HStack(spacing: 12) {
                            Image(systemName: "hammer.fill")
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.ember)

                            Text(pr.exercise.primaryName)
                                .font(Theme.Typography.cardTitle)
                                .foregroundStyle(Theme.Colors.textPrimary)

                            Spacer()

                            Text("\(formatKg(pr.estimated1RM)) kg")
                                .font(.system(size: 17, weight: .bold, design: .default).monospacedDigit())
                                .foregroundStyle(Theme.Colors.ember)

                            if let delta = pr.deltaKg {
                                Text("(+\(formatKg(delta)))")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.ember)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .strokeBorder(Theme.Colors.ember, lineWidth: 2)
                        )
                    }
                } else {
                    VStack(spacing: 12) {
                        Text(L10n.t("又添一锤", "Another Strike"))
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)

                        Text(L10n.t("\(summary.completedSets) 组完成", "\(summary.completedSets) Sets Done"))
                            .font(.system(size: 48, weight: .bold, design: .default).monospacedDigit())
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text(L10n.t("今日训练圆满达成", "Workout complete"))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }

                Spacer()

                // Stat Row
                HStack {
                    stat(value: durationText, label: L10n.t("时长", "Duration"))
                    stat(value: volumeText, label: L10n.t("总容量 kg", "Volume kg"))
                    stat(value: "\(summary.completedSets)", label: L10n.t("组数", "Sets"))
                    stat(value: L10n.t("\(summary.streakWeeks) 周", "\(summary.streakWeeks) wks"), label: L10n.t("连续周数", "Streak"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Theme.Colors.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                )

                // Earned Badges Strip beneath stats
                if !achievements.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(achievements.prefix(3)) { ach in
                            HStack(spacing: 6) {
                                Image(systemName: ach.systemImage)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(ach.badgeColor)
                                Text(ach.name)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.stamp))
                        }
                    }
                    .padding(.top, 10)
                }

                Text(summary.name)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(width: 360, height: 450)
    }

    private var scoreScopeText: String {
        if let lift = summary.tierMoment?.lift {
            return L10n.t("\(lift.displayName) 力量分", "\(lift.displayName) Score")
        } else if let pr = topPR, let coreLift = pr.exercise.coreLift {
            return L10n.t("\(coreLift.displayName) 力量分", "\(coreLift.displayName) Score")
        }
        return L10n.t("力量分", "Score")
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .default).monospacedDigit())
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var durationText: String {
        let total = Int(summary.duration)
        let h = total / 3600, m = (total % 3600) / 60
        return h > 0
            ? L10n.t("\(h)时\(m)分", "\(h)h \(m)m")
            : L10n.t("\(m)分钟", "\(m) min")
    }

    private var volumeText: String {
        let v = summary.totalVolumeKg
        return v >= 1000 ? String(format: "%.1fk", v / 1000) : "\(Int(v))"
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

/// Tier-Up Hero Share Card: Tier badge and name are the hero, session stats are secondary.
struct TierUpShareCardView: View {
    let summary: WorkoutManager.Summary
    let tierMoment: WorkoutManager.TierMoment

    var body: some View {
        ZStack {
            Theme.Colors.surfaceBase

            VStack(spacing: 0) {
                // Header Branding
                HStack {
                    Text("铁证 IRODENCE")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .tracking(2)

                    Spacer()

                    Text(Date(), format: .dateTime.year().month().day())
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                Spacer()

                // Hero: Metallic Tier Badge & Name
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.surfaceRaised)
                            .frame(width: 96, height: 96)
                            .overlay(
                                Circle()
                                    .strokeBorder(tierMoment.tier.color, lineWidth: 3)
                            )
                            .shadow(color: tierMoment.tier.color.opacity(0.4), radius: 20)

                        Image(systemName: tierMoment.tier.systemImage)
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(tierMoment.tier.color)
                    }

                    VStack(spacing: 4) {
                        Text(L10n.t("段位淬火晋升", "Tier Promoted"))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textMuted)
                            .tracking(2)

                        Text("\(tierMoment.lift.displayName) · \(tierMoment.tier.displayName)")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }

                    if let dots = summary.dotsScore {
                        Text(L10n.t(String(format: "%.1f 力量分", dots), String(format: "%.1f Score", dots)))
                            .font(Theme.Typography.cardTitle)
                            .foregroundStyle(Theme.Colors.ember)
                    }
                }

                Spacer()

                // Secondary: Session Stats Row
                HStack {
                    stat(value: durationText, label: L10n.t("时长", "Duration"))
                    stat(value: volumeText, label: L10n.t("总容量 kg", "Volume kg"))
                    stat(value: "\(summary.completedSets)", label: L10n.t("组数", "Sets"))
                    stat(value: L10n.t("\(summary.streakWeeks) 周", "\(summary.streakWeeks) wks"), label: L10n.t("连续周数", "Streak"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Theme.Colors.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                )
                .padding(.bottom, 12)

                Text(summary.name)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .padding(24)
        }
        .frame(width: 360, height: 450)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .default).monospacedDigit())
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var durationText: String {
        let total = Int(summary.duration)
        let h = total / 3600, m = (total % 3600) / 60
        return h > 0
            ? L10n.t("\(h)时\(m)分", "\(h)h \(m)m")
            : L10n.t("\(m)分钟", "\(m) min")
    }

    private var volumeText: String {
        let v = summary.totalVolumeKg
        return v >= 1000 ? String(format: "%.1fk", v / 1000) : "\(Int(v))"
    }
}
