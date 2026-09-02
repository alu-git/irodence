import Foundation

/// Casual Gym Moment post (泵感日常 / 练后打卡).
/// Low-pressure, casual fitness moments (pump selfie, gym fit, daily check-in, nutrition)
/// without requiring 1RM validation or video verification.
struct GymMoment: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    var userDisplayName: String
    var userTierName: String?        // e.g. "熟铁", "精钢"
    var userCrewName: String?
    var visibilityText: String?      // e.g. "仅熔炉可见", "社区公开"
    var imageURL: String?
    var localImageData: Data?
    var caption: String?
    var workoutName: String?         // e.g. "推力日"
    var workoutDurationText: String? // e.g. "1h 15m"
    var workoutVolumeText: String?   // e.g. "容量 8.4t"
    var tags: [String]
    var fistBumpCount: Int           // 碰拳数
    var fistBumpedByMe: Bool
    var fireCount: Int               // 加炭数
    var firedByMe: Bool
    var commentCount: Int
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case userDisplayName = "user_display_name"
        case userTierName = "user_tier_name"
        case userCrewName = "user_crew_name"
        case visibilityText = "visibility_text"
        case imageURL = "image_url"
        case caption
        case workoutName = "workout_name"
        case workoutDurationText = "workout_duration_text"
        case workoutVolumeText = "workout_volume_text"
        case tags
        case fistBumpCount = "fist_bump_count"
        case fistBumpedByMe = "fist_bumped_by_me"
        case fireCount = "fire_count"
        case firedByMe = "fired_by_me"
        case commentCount = "comment_count"
        case createdAt = "created_at"
    }
}
