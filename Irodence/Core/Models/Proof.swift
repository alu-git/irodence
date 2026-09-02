import Foundation

/// Proof visibility scope per IRODENCE_SAFETY.md Section 2:
/// "Proof video visibility default: 仅熔炉可见 (crew only)"
public enum ProofVisibility: String, Codable, CaseIterable {
    case crewOnly = "crew_only"
    case publicFeed = "public"

    public var displayName: String {
        switch self {
        case .crewOnly: return L10n.t("仅熔炉可见 (默认)", "Crew Only (Default)")
        case .publicFeed: return L10n.t("公域可见", "Public")
        }
    }
}

/// A Proof (证词) is a PR attempt with optional video submission.
/// Defined in IRODENCE_DESIGN.md and IRODENCE_SAFETY.md.
public struct Proof: Identifiable, Codable, Hashable {
    public let id: UUID
    public let userID: UUID
    public let exerciseID: UUID
    public let weightKg: Double
    public let reps: Int
    public let estimated1RM: Double
    public let dotsScore: Double
    public let tier: String
    public let videoURL: String?
    public let notes: String?
    public let status: ProofStatus
    public let isCertified: Bool
    public let certifiedAt: Date?
    public let confirmCount: Int
    public let flagCount: Int
    public let visibility: ProofVisibility
    public let moderationStatus: String
    public let achievedAt: Date
    public let createdAt: Date
    public let updatedAt: Date

    public var likeCount: Int
    public var likedByMe: Bool
    public var commentCount: Int

    // Profile metadata when joined
    public var userDisplayName: String?
    public var userAvatarURL: String?
    public var exerciseNameZh: String?
    public var exerciseNameEn: String?

    public var exerciseDisplayName: String {
        if AppLanguage.isEnglish, let en = exerciseNameEn, !en.isEmpty {
            return en
        }
        return exerciseNameZh ?? L10n.t("核心动作", "Core Lift")
    }

    public init(
        id: UUID = UUID(),
        userID: UUID,
        exerciseID: UUID,
        weightKg: Double,
        reps: Int,
        estimated1RM: Double,
        dotsScore: Double,
        tier: String,
        videoURL: String? = nil,
        notes: String? = nil,
        status: ProofStatus = .pending,
        isCertified: Bool = false,
        certifiedAt: Date? = nil,
        confirmCount: Int = 0,
        flagCount: Int = 0,
        visibility: ProofVisibility = .crewOnly,
        moderationStatus: String = "approved",
        achievedAt: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        likeCount: Int = 0,
        likedByMe: Bool = false,
        commentCount: Int = 0,
        userDisplayName: String? = nil,
        userAvatarURL: String? = nil,
        exerciseNameZh: String? = nil,
        exerciseNameEn: String? = nil
    ) {
        self.id = id
        self.userID = userID
        self.exerciseID = exerciseID
        self.weightKg = weightKg
        self.reps = reps
        self.estimated1RM = estimated1RM
        self.dotsScore = dotsScore
        self.tier = tier
        self.videoURL = videoURL
        self.notes = notes
        self.status = status
        self.isCertified = isCertified
        self.certifiedAt = certifiedAt
        self.confirmCount = confirmCount
        self.flagCount = flagCount
        self.visibility = visibility
        self.moderationStatus = moderationStatus
        self.achievedAt = achievedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.likeCount = likeCount
        self.likedByMe = likedByMe
        self.commentCount = commentCount
        self.userDisplayName = userDisplayName
        self.userAvatarURL = userAvatarURL
        self.exerciseNameZh = exerciseNameZh
        self.exerciseNameEn = exerciseNameEn
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case exerciseID = "exercise_id"
        case weightKg = "weight_kg"
        case reps
        case estimated1RM = "estimated_1rm"
        case dotsScore = "dots_score"
        case tier
        case videoURL = "video_url"
        case notes
        case status
        case isCertified = "is_certified"
        case certifiedAt = "certified_at"
        case confirmCount = "confirm_count"
        case flagCount = "flag_count"
        case visibility
        case moderationStatus = "moderation_status"
        case achievedAt = "achieved_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userDisplayName = "display_name"
        case userAvatarURL = "avatar_url"
        case exerciseNameZh = "name_zh"
        case profiles
        case exercises
    }

    private struct JoinedProfile: Decodable {
        let displayName: String?
        let avatarURL: String?
        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case avatarURL = "avatar_url"
        }
    }

    private struct JoinedExercise: Decodable {
        let nameZh: String?
        enum CodingKeys: String, CodingKey {
            case nameZh = "name_zh"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userID = try container.decode(UUID.self, forKey: .userID)
        exerciseID = try container.decode(UUID.self, forKey: .exerciseID)
        weightKg = try container.decode(Double.self, forKey: .weightKg)
        reps = try container.decode(Int.self, forKey: .reps)
        estimated1RM = try container.decode(Double.self, forKey: .estimated1RM)
        dotsScore = (try? container.decode(Double.self, forKey: .dotsScore)) ?? 0.0
        tier = (try? container.decode(String.self, forKey: .tier)) ?? "pig_iron"
        videoURL = try? container.decode(String.self, forKey: .videoURL)
        notes = try? container.decode(String.self, forKey: .notes)
        status = (try? container.decode(ProofStatus.self, forKey: .status)) ?? .pending
        isCertified = (try? container.decode(Bool.self, forKey: .isCertified)) ?? false
        certifiedAt = try? container.decode(Date.self, forKey: .certifiedAt)
        confirmCount = (try? container.decode(Int.self, forKey: .confirmCount)) ?? 0
        flagCount = (try? container.decode(Int.self, forKey: .flagCount)) ?? 0
        visibility = (try? container.decode(ProofVisibility.self, forKey: .visibility)) ?? .crewOnly
        moderationStatus = (try? container.decode(String.self, forKey: .moderationStatus)) ?? "approved"
        achievedAt = (try? container.decode(Date.self, forKey: .achievedAt)) ?? Date()
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? Date()
        likeCount = (try? container.decode(Int.self, forKey: .confirmCount)) ?? 0
        likedByMe = false
        commentCount = 0

        // Decode joined profiles or flat fields
        if let prof = try? container.decode(JoinedProfile.self, forKey: .profiles) {
            userDisplayName = prof.displayName
            userAvatarURL = prof.avatarURL
        } else {
            userDisplayName = try? container.decode(String.self, forKey: .userDisplayName)
            userAvatarURL = try? container.decode(String.self, forKey: .userAvatarURL)
        }

        // Decode joined exercises or flat fields
        if let ex = try? container.decode(JoinedExercise.self, forKey: .exercises) {
            exerciseNameZh = ex.nameZh
        } else {
            exerciseNameZh = try? container.decode(String.self, forKey: .exerciseNameZh)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userID, forKey: .userID)
        try container.encode(exerciseID, forKey: .exerciseID)
        try container.encode(weightKg, forKey: .weightKg)
        try container.encode(reps, forKey: .reps)
        try container.encode(estimated1RM, forKey: .estimated1RM)
        try container.encode(dotsScore, forKey: .dotsScore)
        try container.encode(tier, forKey: .tier)
        try container.encodeIfPresent(videoURL, forKey: .videoURL)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(status, forKey: .status)
        try container.encode(isCertified, forKey: .isCertified)
        try container.encodeIfPresent(certifiedAt, forKey: .certifiedAt)
        try container.encode(confirmCount, forKey: .confirmCount)
        try container.encode(flagCount, forKey: .flagCount)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(moderationStatus, forKey: .moderationStatus)
        try container.encode(achievedAt, forKey: .achievedAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(userDisplayName, forKey: .userDisplayName)
        try container.encodeIfPresent(userAvatarURL, forKey: .userAvatarURL)
        try container.encodeIfPresent(exerciseNameZh, forKey: .exerciseNameZh)
    }
}

public enum ProofStatus: String, Codable {
    case pending
    case certified
    case underReview = "under_review"
    case rejected

    public var displayName: String {
        switch self {
        case .pending: return L10n.t("待见证", "Pending")
        case .certified: return L10n.t("已认证", "Certified")
        case .underReview: return L10n.t("审核中", "Under Review")
        case .rejected: return L10n.t("未通过", "Rejected")
        }
    }
}

/// A Witness (见证) record on a proof.
public struct Witness: Identifiable, Codable, Hashable {
    public let id: UUID
    public let proofID: UUID
    public let witnessID: UUID
    public let action: WitnessAction
    public let comment: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        proofID: UUID,
        witnessID: UUID,
        action: WitnessAction,
        comment: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.proofID = proofID
        self.witnessID = witnessID
        self.action = action
        self.comment = comment
        self.createdAt = createdAt
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case proofID = "proof_id"
        case witnessID = "witness_id"
        case action
        case comment
        case createdAt = "created_at"
    }
}

public enum WitnessAction: String, Codable {
    case confirm
    case flag
}
