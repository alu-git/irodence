import Foundation

/// Row in `public.profiles`.
struct Profile: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var avatarURL: String?
    var sex: Sex?
    var bodyweightKg: Double?

    enum CodingKeys: String, CodingKey {
        case id, sex
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case bodyweightKg = "bodyweight_kg"
    }
}
