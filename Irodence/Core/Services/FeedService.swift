import Foundation
import Supabase

/// One set inside a feed workout (from the view's `sets` jsonb array).
struct FeedSet: Decodable, Hashable {
    let weightKg: Double
    let reps: Int
    let isWarmup: Bool

    enum CodingKeys: String, CodingKey {
        case reps
        case weightKg = "weight_kg"
        case isWarmup = "is_warmup"
    }

    /// "60.5" stays decimal, "60" drops the trailing zero.
    var weightText: String {
        weightKg.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weightKg))"
            : String(format: "%.1f", weightKg)
    }
}

/// One exercise inside a feed workout, with SQL-computed numbers
/// (from the view's `exercise_summaries` jsonb array, ordered).
struct FeedExerciseSummary: Identifiable, Decodable, Hashable {
    let nameZh: String
    let nameEn: String
    let primaryMuscle: MuscleGroup
    let setCount: Int
    let volumeKg: Double
    let bestWeightKg: Double?
    let bestReps: Int?
    let sets: [FeedSet]

    var id: String { nameEn }

    enum CodingKeys: String, CodingKey {
        case sets
        case nameZh = "name_zh"
        case nameEn = "name_en"
        case primaryMuscle = "primary_muscle"
        case setCount = "set_count"
        case volumeKg = "volume_kg"
        case bestWeightKg = "best_weight_kg"
        case bestReps = "best_reps"
    }

    /// Display name — follows the in-app language setting (中文 default).
    var displayName: String { AppLanguage.isEnglish ? nameEn : nameZh }

    /// Muscle activation for the mini diagram: curated override by name_en,
    /// else the muscle-group fallback.
    var muscles: ExerciseMuscles {
        ExerciseMuscleMap.muscles(nameEn: nameEn, primaryMuscle: primaryMuscle)
    }

    /// One-line numbers for the feed card, e.g. "3 组 · 最佳 60 kg × 8".
    var compactNumbersText: String {
        var parts = ["\(setCount) \(L10n.t("组", "sets"))"]
        if let weight = bestWeightKg, let reps = bestReps {
            let w = weight.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(weight))" : String(format: "%.1f", weight)
            parts.append(L10n.t("最佳", "best") + " \(w) kg × \(reps)")
        }
        return parts.joined(separator: " · ")
    }
}

/// One row of the `workout_feed` view: a finished workout by you or
/// someone you follow, with SQL-computed aggregates and like state.
struct FeedItem: Identifiable, Decodable, Hashable {
    let id: UUID
    let userID: UUID
    let displayName: String
    let name: String
    let startedAt: Date
    let finishedAt: Date
    let exerciseCount: Int
    let setCount: Int
    let totalVolumeKg: Double
    let exercises: [FeedExerciseSummary]
    var likeCount: Int
    var likedByMe: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case userID = "user_id"
        case displayName = "display_name"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case exerciseCount = "exercise_count"
        case setCount = "set_count"
        case totalVolumeKg = "total_volume_kg"
        case exercises = "exercise_summaries"
        case likeCount = "like_count"
        case likedByMe = "liked_by_me"
    }

    var durationText: String {
        let total = Int(finishedAt.timeIntervalSince(startedAt))
        let h = total / 3600, m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    var volumeText: String {
        totalVolumeKg >= 1000
            ? String(format: "%.1fk kg", totalVolumeKg / 1000)
            : "\(Int(totalVolumeKg)) kg"
    }

    var relativeTimeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: finishedAt, relativeTo: Date())
    }
}

/// The social feed: workouts from you + your followees, with likes.
@MainActor
final class FeedService: ObservableObject {
    @Published private(set) var items: [FeedItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseService.client
    private let userID: UUID

    /// The signed-in viewer (used when pushing profile destinations).
    var viewerID: UUID { userID }

    init(userID: UUID) {
        self.userID = userID
    }

    /// Loads the feed — everyone visible (nil), or one person's workouts
    /// (profile page). Visibility rules live inside the view either way.
    func load(filterUserID: UUID? = nil) async {
        isLoading = items.isEmpty
        defer { isLoading = false }
        do {
            if let filterUserID {
                items = try await client
                    .from("workout_feed")
                    .select()
                    .eq("user_id", value: filterUserID)
                    .limit(50)
                    .execute()
                    .value
            } else {
                items = try await client
                    .from("workout_feed")
                    .select()
                    .limit(50)
                    .execute()
                    .value
            }
        } catch {
            if items.isEmpty {
                errorMessage = L10n.t("动态加载失败", "Couldn't load the feed")
            }
        }
    }

    struct LikeInsert: Encodable {
        let workout_id: UUID
        let user_id: UUID
    }

    /// Optimistic like/unlike with rollback on failure.
    func toggleLike(_ item: FeedItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let wasLiked = item.likedByMe
        items[index].likedByMe = !wasLiked
        items[index].likeCount += wasLiked ? -1 : 1
        do {
            if wasLiked {
                try await client
                    .from("workout_likes")
                    .delete()
                    .eq("workout_id", value: item.id)
                    .eq("user_id", value: userID)
                    .execute()
            } else {
                try await client
                    .from("workout_likes")
                    .insert(LikeInsert(workout_id: item.id, user_id: userID))
                    .execute()
            }
        } catch {
            items[index] = item
        }
    }
}
