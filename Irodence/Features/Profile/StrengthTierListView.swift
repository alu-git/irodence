import SwiftUI

/// Visual roadmap of all 6 forged metal tiers with icons, colors, descriptions,
/// and highlighting for the user's current tier.
/// Follows IRODENCE_PALETTE.md and IRODENCE_DESIGN.md visual language.
struct StrengthTierListView: View {
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue
    let currentTier: StrengthTier?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)
                Text(L10n.t("锻造段位阶梯", "Forge Tier Roadmap"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(StrengthTier.allCases.reversed(), id: \.self) { tier in
                    tierRow(tier)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    private func tierRow(_ tier: StrengthTier) -> some View {
        let isCurrent = currentTier == tier

        return HStack(spacing: 14) {
            // Icon Badge
            Image(tier.assetImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(isCurrent ? Theme.Colors.ember : tier.color.opacity(0.3), lineWidth: isCurrent ? 2 : 1)
                )
                .shadow(color: isCurrent ? Theme.Colors.ember.opacity(0.3) : Color.clear, radius: 8)
                .metallicSheen(trigger: isCurrent, duration: 0.8, delay: 0.3)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(tier.displayName)
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundStyle(isCurrent ? Theme.Colors.ember : Theme.Colors.textPrimary)

                    if isCurrent {
                        Text(L10n.t("当前段位", "Current Tier"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Colors.emberDeep)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Theme.Colors.ember, in: Capsule())
                    }
                }

                Text(tierDescription(tier))
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(isCurrent ? Theme.Colors.textSecondary : Theme.Colors.textMuted)
                    .lineLimit(2)
            }

            Spacer()

            // Status indicator
            if isCurrent {
                Circle()
                    .fill(Theme.Colors.ember)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .strokeBorder(Theme.Colors.borderMetal, lineWidth: 1)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(isCurrent ? Theme.Colors.surfaceSunken : Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .strokeBorder(isCurrent ? Theme.Colors.ember : Theme.Colors.borderMetal.opacity(0.6), lineWidth: isCurrent ? 1.5 : Theme.Border.hairline)
        )
    }

    private func tierDescription(_ tier: StrengthTier) -> String {
        switch tier {
        case .pigIron:
            return L10n.t("初入铁砧，锻铸基础力量与标准动作", "Novice — building baseline strength and learning form")
        case .wroughtIron:
            return L10n.t("淬炼成型，掌握核心项技术并稳步成长", "Early Intermediate — steady progression on compound lifts")
        case .castSteel:
            return L10n.t("扎实坚韧，突破三大项百公斤等标志里程碑", "Intermediate — breaking milestone plates with solid mechanics")
        case .refinedSteel:
            return L10n.t("千锤百炼，达到高阶扎实力量水准", "Advanced — well above gym average with formidable numbers")
        case .reforged:
            return L10n.t("重构极限，跻身竞技比赛顶尖水平", "Elite — competitive lifter numbers pushing human limits")
        case .hundredFold:
            return L10n.t("百炼纯钢，国家级与世界级传奇力量", "Masterwork — world-class podium strength")
        }
    }
}
