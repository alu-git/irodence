import Foundation

/// A Challenge (比武) is a head-to-head 力量分 gain contest over a fixed window.
/// Defined in IRODENCE_DESIGN.md.
public struct Challenge: Identifiable, Codable, Hashable {
    public let id: UUID
    public let challengerID: UUID
    public let challengedID: UUID
    public let exerciseID: UUID?
    public let startDate: String
    public let endDate: String
    public let challengerBaseline: Double
    public let challengedBaseline: Double
    public let challengerGain: Double
    public let challengedGain: Double
    public let status: ChallengeStatus
    public let winnerID: UUID?
    public let createdAt: Date
    public let updatedAt: Date

    // Joined Profile metadata
    public var challengerName: String?
    public var challengerAvatarURL: String?
    public var challengedName: String?
    public var challengedAvatarURL: String?

    public init(
        id: UUID = UUID(),
        challengerID: UUID,
        challengedID: UUID,
        exerciseID: UUID? = nil,
        startDate: String,
        endDate: String,
        challengerBaseline: Double = 0.0,
        challengedBaseline: Double = 0.0,
        challengerGain: Double = 0.0,
        challengedGain: Double = 0.0,
        status: ChallengeStatus = .pending,
        winnerID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        challengerName: String? = nil,
        challengerAvatarURL: String? = nil,
        challengedName: String? = nil,
        challengedAvatarURL: String? = nil
    ) {
        self.id = id
        self.challengerID = challengerID
        self.challengedID = challengedID
        self.exerciseID = exerciseID
        self.startDate = startDate
        self.endDate = endDate
        self.challengerBaseline = challengerBaseline
        self.challengedBaseline = challengedBaseline
        self.challengerGain = challengerGain
        self.challengedGain = challengedGain
        self.status = status
        self.winnerID = winnerID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.challengerName = challengerName
        self.challengerAvatarURL = challengerAvatarURL
        self.challengedName = challengedName
        self.challengedAvatarURL = challengedAvatarURL
    }

    public var localizedChallengerName: String {
        guard let name = challengerName else { return L10n.t("铁友", "Lifter") }
        if name == "大力水手" {
            return L10n.t("大力水手", "Popeye")
        } else if name == "闪电麦昆" {
            return L10n.t("闪电麦昆", "Lightning McQueen")
        } else if name == "铁牛" {
            return L10n.t("铁牛", "Iron Ox")
        } else if name == "小钢炮" {
            return L10n.t("小钢炮", "Pocket Rocket")
        }
        return name
    }

    public var localizedChallengedName: String {
        guard let name = challengedName else { return L10n.t("你", "You") }
        if name == "你" {
            return L10n.t("你", "You")
        }
        return name
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case challengerID = "challenger_id"
        case challengedID = "challenged_id"
        case exerciseID = "exercise_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case challengerBaseline = "challenger_baseline"
        case challengedBaseline = "challenged_baseline"
        case challengerGain = "challenger_gain"
        case challengedGain = "challenged_gain"
        case status
        case winnerID = "winner_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case challengerName = "challenger_name"
        case challengerAvatarURL = "challenger_avatar_url"
        case challengedName = "challenged_name"
        case challengedAvatarURL = "challenged_avatar_url"
        case challenger
        case challenged
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
        challengerID = try container.decode(UUID.self, forKey: .challengerID)
        challengedID = try container.decode(UUID.self, forKey: .challengedID)
        exerciseID = try? container.decode(UUID.self, forKey: .exerciseID)
        startDate = try container.decode(String.self, forKey: .startDate)
        endDate = try container.decode(String.self, forKey: .endDate)
        challengerBaseline = (try? container.decode(Double.self, forKey: .challengerBaseline)) ?? 0.0
        challengedBaseline = (try? container.decode(Double.self, forKey: .challengedBaseline)) ?? 0.0
        challengerGain = (try? container.decode(Double.self, forKey: .challengerGain)) ?? 0.0
        challengedGain = (try? container.decode(Double.self, forKey: .challengedGain)) ?? 0.0
        status = (try? container.decode(ChallengeStatus.self, forKey: .status)) ?? .pending
        winnerID = try? container.decode(UUID.self, forKey: .winnerID)
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? Date()

        if let prof = try? container.decode(JoinedProfile.self, forKey: .challenger) {
            challengerName = prof.displayName
            challengerAvatarURL = prof.avatarURL
        } else {
            challengerName = try? container.decode(String.self, forKey: .challengerName)
            challengerAvatarURL = try? container.decode(String.self, forKey: .challengerAvatarURL)
        }

        if let prof = try? container.decode(JoinedProfile.self, forKey: .challenged) {
            challengedName = prof.displayName
            challengedAvatarURL = prof.avatarURL
        } else {
            challengedName = try? container.decode(String.self, forKey: .challengedName)
            challengedAvatarURL = try? container.decode(String.self, forKey: .challengedAvatarURL)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(challengerID, forKey: .challengerID)
        try container.encode(challengedID, forKey: .challengedID)
        try container.encodeIfPresent(exerciseID, forKey: .exerciseID)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(challengerBaseline, forKey: .challengerBaseline)
        try container.encode(challengedBaseline, forKey: .challengedBaseline)
        try container.encode(challengerGain, forKey: .challengerGain)
        try container.encode(challengedGain, forKey: .challengedGain)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(winnerID, forKey: .winnerID)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(challengerName, forKey: .challengerName)
        try container.encodeIfPresent(challengerAvatarURL, forKey: .challengerAvatarURL)
        try container.encodeIfPresent(challengedName, forKey: .challengedName)
        try container.encodeIfPresent(challengedAvatarURL, forKey: .challengedAvatarURL)
    }
}

public enum ChallengeStatus: String, Codable {
    case pending
    case active
    case completed
    case declined
    case cancelled

    public var displayName: String {
        switch self {
        case .pending: return L10n.t("待应战", "Pending")
        case .active: return L10n.t("激战中", "Active")
        case .completed: return L10n.t("已结束", "Completed")
        case .declined: return L10n.t("已拒绝", "Declined")
        case .cancelled: return L10n.t("已取消", "Cancelled")
        }
    }
}
