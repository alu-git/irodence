import Foundation

/// Row in `public.profiles`.
struct Profile: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var avatarURL: String?
    var sex: Sex?
    var bodyweightKg: Double?
    var bio: String?
    var heightCm: Double?
    var ageYears: Int?

    enum CodingKeys: String, CodingKey {
        case id, sex, bio
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case bodyweightKg = "bodyweight_kg"
        case heightCm = "height_cm"
        case ageYears = "age_years"
    }

    private enum AltCodingKeys: String, CodingKey {
        case age
    }

    init(id: UUID, displayName: String, avatarURL: String? = nil, sex: Sex? = nil, bodyweightKg: Double? = nil, bio: String? = nil, heightCm: Double? = nil, ageYears: Int? = nil) {
        self.id = id
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.sex = sex
        self.bodyweightKg = bodyweightKg
        self.bio = bio
        self.heightCm = heightCm
        self.ageYears = ageYears
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? L10n.t("老铁", "Lifter")
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        sex = try container.decodeIfPresent(Sex.self, forKey: .sex)
        bodyweightKg = try container.decodeIfPresent(Double.self, forKey: .bodyweightKg)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        heightCm = try container.decodeIfPresent(Double.self, forKey: .heightCm)
        ageYears = try container.decodeIfPresent(Int.self, forKey: .ageYears)
        if ageYears == nil, let altContainer = try? decoder.container(keyedBy: AltCodingKeys.self) {
            ageYears = try altContainer.decodeIfPresent(Int.self, forKey: .age)
        }
    }
}
