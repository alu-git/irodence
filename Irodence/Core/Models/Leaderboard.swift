import Foundation

/// Row in the `leaderboard_entries` view: one user's best on one lift.
struct LeaderboardEntry: Identifiable, Codable, Hashable {
    var id: UUID { userID }
    let userID: UUID
    let displayName: String
    let avatarURL: String?
    let sex: Sex?
    let bodyweightKg: Double?
    let exerciseID: UUID
    let weightKg: Double
    let reps: Int
    let estimated1RM: Double
    let achievedAt: Date

    enum CodingKeys: String, CodingKey {
        case reps, sex
        case userID = "user_id"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case bodyweightKg = "bodyweight_kg"
        case exerciseID = "exercise_id"
        case weightKg = "weight_kg"
        case estimated1RM = "estimated_1rm"
        case achievedAt = "achieved_at"
    }

    /// DOTS only computable when the user's sex + bodyweight are set.
    var dotsScore: Double? {
        guard let sex, let bodyweightKg else { return nil }
        return DOTSCalculator.score(liftedKg: estimated1RM, bodyweightKg: bodyweightKg, sex: sex)
    }

    var tier: StrengthTier? {
        guard let sex, let dotsScore, let lift = CoreLift(exerciseID: exerciseID) else { return nil }
        return StrengthStandards.tier(for: dotsScore, lift: lift, sex: sex)
    }
}

/// Row in the `weekly_volume` view.
struct WeeklyVolumeEntry: Identifiable, Codable, Hashable {
    var id: UUID { userID }
    let userID: UUID
    let displayName: String
    let avatarURL: String?
    let totalVolumeKg: Double
    let totalSets: Int

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case totalVolumeKg = "total_volume_kg"
        case totalSets = "total_sets"
    }
}

extension CoreLift {
    /// Reverse lookup from a seeded exercise UUID.
    init?(exerciseID: UUID) {
        guard let match = ExerciseIDCache.shared.lift(for: exerciseID) else { return nil }
        self = match
    }
}

/// Caches the exercise-library UUID for each core lift so tier/DOTS lookups
/// don't need the full library on hand. Populated when the library loads.
final class ExerciseIDCache {
    static let shared = ExerciseIDCache()
    private var byExerciseID: [UUID: CoreLift] = [:]

    func register(exerciseID: UUID, nameEn: String) {
        if let lift = CoreLift.allCases.first(where: { $0.exerciseNameEn == nameEn }) {
            byExerciseID[exerciseID] = lift
        }
    }

    func lift(for exerciseID: UUID) -> CoreLift? {
        byExerciseID[exerciseID]
    }
}
