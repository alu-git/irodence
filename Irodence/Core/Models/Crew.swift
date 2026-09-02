import Foundation

/// A Crew (熔炉) is a 4–20 member collective strength group.
/// Defined in IRODENCE_DESIGN.md.
public struct Crew: Identifiable, Codable, Hashable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let avatarURL: String?
    public let createdBy: UUID
    public let weeklyHeatTarget: Int
    public let memberCount: Int
    public let isActive: Bool
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        avatarURL: String? = nil,
        createdBy: UUID,
        weeklyHeatTarget: Int = 100,
        memberCount: Int = 1,
        isActive: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.avatarURL = avatarURL
        self.createdBy = createdBy
        self.weeklyHeatTarget = weeklyHeatTarget
        self.memberCount = memberCount
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var localizedName: String {
        if name == "玄铁重工" {
            return L10n.t("玄铁重工", "Dark Iron Forge")
        }
        return name
    }

    public var localizedDescription: String? {
        guard let desc = description else { return nil }
        if desc == "同炉淬火，生锈必催" {
            return L10n.t("同炉淬火，生锈必催", "Quench together, rust never")
        }
        return desc
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case avatarURL = "avatar_url"
        case createdBy = "created_by"
        case weeklyHeatTarget = "weekly_heat_target"
        case memberCount = "member_count"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// A Crew Member (熔炉成员) with strike tracking and rust state.
public struct CrewMember: Identifiable, Codable, Hashable {
    public let id: UUID
    public let crewID: UUID
    public let userID: UUID
    public let role: String
    public let strikesCount: Int
    public let lastActiveAt: Date
    public let joinedAt: Date

    // Profile metadata
    public var displayName: String?
    public var avatarURL: String?

    public var localizedDisplayName: String {
        guard let name = displayName else { return L10n.t("铁友", "Lifter") }
        if name == "铁友 (你)" || name == "铁友" {
            return L10n.t("铁友 (你)", "Lifter (You)")
        } else if name == "大力水手" {
            return L10n.t("大力水手", "Popeye")
        } else if name == "闪电麦昆" {
            return L10n.t("闪电麦昆", "Lightning McQueen")
        } else if name == "铁牛" {
            return L10n.t("铁牛", "Iron Ox")
        } else if name == "小钢炮" {
            return L10n.t("小钢炮", "Pocket Rocket")
        } else if name == "腿王" {
            return L10n.t("腿王", "Leg King")
        } else if name == "老王" {
            return L10n.t("老王", "Coach Wang")
        } else if name == "Alice爱撸铁" {
            return L10n.t("Alice爱撸铁", "Alice Lifts")
        }
        return name
    }

    public init(
        id: UUID = UUID(),
        crewID: UUID,
        userID: UUID,
        role: String = "member",
        strikesCount: Int = 0,
        lastActiveAt: Date = Date(),
        joinedAt: Date = Date(),
        displayName: String? = nil,
        avatarURL: String? = nil
    ) {
        self.id = id
        self.crewID = crewID
        self.userID = userID
        self.role = role
        self.strikesCount = strikesCount
        self.lastActiveAt = lastActiveAt
        self.joinedAt = joinedAt
        self.displayName = displayName
        self.avatarURL = avatarURL
    }

    public var isRusted: Bool {
        Date().timeIntervalSince(lastActiveAt) >= 7 * 86_400
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case crewID = "crew_id"
        case userID = "user_id"
        case role
        case strikesCount = "strikes_count"
        case lastActiveAt = "last_active_at"
        case joinedAt = "joined_at"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case profiles
    }

    private struct JoinedProfile: Decodable {
        let displayName: String?
        let avatarURL: String?
        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case avatarURL = "avatar_url"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        crewID = try container.decode(UUID.self, forKey: .crewID)
        userID = try container.decode(UUID.self, forKey: .userID)
        role = try container.decode(String.self, forKey: .role)
        strikesCount = (try? container.decode(Int.self, forKey: .strikesCount)) ?? 0
        lastActiveAt = (try? container.decode(Date.self, forKey: .lastActiveAt)) ?? Date()
        joinedAt = (try? container.decode(Date.self, forKey: .joinedAt)) ?? Date()

        if let prof = try? container.decode(JoinedProfile.self, forKey: .profiles) {
            displayName = prof.displayName
            avatarURL = prof.avatarURL
        } else {
            displayName = try? container.decode(String.self, forKey: .displayName)
            avatarURL = try? container.decode(String.self, forKey: .avatarURL)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(crewID, forKey: .crewID)
        try container.encode(userID, forKey: .userID)
        try container.encode(role, forKey: .role)
        try container.encode(strikesCount, forKey: .strikesCount)
        try container.encode(lastActiveAt, forKey: .lastActiveAt)
        try container.encode(joinedAt, forKey: .joinedAt)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
    }
}

/// Weekly Crew Heat (炉温) & Quenching (淬火) status.
public struct CrewHeat: Identifiable, Codable, Hashable {
    public let id: UUID
    public let crewID: UUID
    public let weekStart: String
    public let totalHeat: Int
    public let targetHeat: Int
    public let isQuenched: Bool
    public let quenchedAt: Date?

    public init(
        id: UUID = UUID(),
        crewID: UUID,
        weekStart: String,
        totalHeat: Int,
        targetHeat: Int,
        isQuenched: Bool = false,
        quenchedAt: Date? = nil
    ) {
        self.id = id
        self.crewID = crewID
        self.weekStart = weekStart
        self.totalHeat = totalHeat
        self.targetHeat = targetHeat
        self.isQuenched = isQuenched
        self.quenchedAt = quenchedAt
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case crewID = "crew_id"
        case weekStart = "week_start"
        case totalHeat = "total_heat"
        case targetHeat = "target_heat"
        case isQuenched = "is_quenched"
        case quenchedAt = "quenched_at"
    }
}
