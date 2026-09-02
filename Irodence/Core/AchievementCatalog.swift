import Foundation
import SwiftUI

/// Category of forged achievements.
enum AchievementCategory: String, Codable {
    case tierUp = "tier_up"
    case firstTime = "first_time"
    case milestone = "milestone"

    var displayName: String {
        switch self {
        case .tierUp: return L10n.t("段位晋升", "Tier Promotion")
        case .firstTime: return L10n.t("初次达成", "First Milestone")
        case .milestone: return L10n.t("熔炉丰碑", "Forge Milestone")
        }
    }

    var sortOrder: Int {
        switch self {
        case .tierUp: return 0
        case .firstTime: return 1
        case .milestone: return 2
        }
    }
}

/// A structured achievement item earned by a lifter.
struct AchievementItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let systemImage: String
    let category: AchievementCategory
    let tier: StrengthTier?

    var badgeColor: Color {
        if let tier = tier {
            return tier.color
        }
        return Theme.Colors.ember
    }

    init(
        id: String,
        name: String,
        description: String,
        systemImage: String,
        category: AchievementCategory,
        tier: StrengthTier? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.systemImage = systemImage
        self.category = category
        self.tier = tier
    }
}

/// Curated catalog of achievements across the forge.
enum AchievementCatalog {
    // 1. Tier-Up Achievements
    static func tierUp(tier: StrengthTier, lift: CoreLift? = nil, exerciseName: String? = nil) -> AchievementItem {
        let name = exerciseName ?? lift?.displayName
        let prefixZh = name != nil ? "\(name!) · " : ""
        let prefixEn = name != nil ? "\(name!) · " : ""
        let key = name ?? lift?.rawValue ?? "overall"
        return AchievementItem(
            id: "tier_\(tier.rawValue)_\(key)",
            name: L10n.t("\(prefixZh)晋升 · \(tier.displayName)", "\(prefixEn)\(tier.displayName) · Promoted"),
            description: L10n.t(
                "在力量的淬炼中突破界限，成功踏入「\(tier.displayName)」段位！百炼成钢，力量跨入新的巅峰。",
                "Pushed past limits in the heat of the forge, reaching [\(tier.displayName)] tier! Forged through sweat and steel to new peaks of strength."
            ),
            systemImage: tier.systemImage,
            category: .tierUp,
            tier: tier
        )
    }

    // 2. First-Time Achievements
    static var firstWorkout: AchievementItem {
        AchievementItem(
            id: "first_workout",
            name: L10n.t("初试锋芒", "First Spark"),
            description: L10n.t("完成在铁炉中的第一场正式训练，铁胚初成。", "Completed your very first official workout in the forge."),
            systemImage: "flame.fill",
            category: .firstTime
        )
    }

    static var firstPR: AchievementItem {
        AchievementItem(
            id: "first_pr",
            name: L10n.t("破晓新力", "Dawn of PR"),
            description: L10n.t("打破属于你的首个单项个人最佳纪录 (PR)。", "Shattered your first individual personal record (PR)."),
            systemImage: "hammer.fill",
            category: .firstTime
        )
    }

    static var firstProof: AchievementItem {
        AchievementItem(
            id: "first_proof",
            name: L10n.t("上铁证", "Stamped in Iron"),
            description: L10n.t("提交首条试举见证视频，开启实证之路。", "Submitted your first lift proof video for peer verification."),
            systemImage: "checkmark.seal.fill",
            category: .firstTime
        )
    }

    // 3. Milestone Achievements
    static var volume10Tons: AchievementItem {
        AchievementItem(
            id: "volume_10_tons",
            name: L10n.t("万钧重锤", "10-Ton Hammer"),
            description: L10n.t("单场训练总吨位突破 10,000 kg (10吨)。", "Moved over 10,000 kg (10 metric tons) of total tonnage in a single session."),
            systemImage: "scalemass.fill",
            category: .milestone
        )
    }

    static var streak4Weeks: AchievementItem {
        AchievementItem(
            id: "streak_4_weeks",
            name: L10n.t("月铸精铁", "Month of Iron"),
            description: L10n.t("连续坚持训练 4 周以上，炉火常明。", "Maintained consistent weekly training for 4+ consecutive weeks."),
            systemImage: "calendar.badge.clock",
            category: .milestone
        )
    }
}
