import Foundation
import Supabase

/// One set inside a feed workout (from the view's `sets` jsonb array).
struct FeedSet: Codable, Hashable {
    let weightKg: Double
    let reps: Int
    let isWarmup: Bool

    enum CodingKeys: String, CodingKey {
        case reps
        case weightKg = "weight_kg"
        case isWarmup = "is_warmup"
    }

    init(weightKg: Double, reps: Int, isWarmup: Bool = false) {
        self.weightKg = weightKg
        self.reps = reps
        self.isWarmup = isWarmup
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
struct FeedExerciseSummary: Identifiable, Codable, Hashable {
    let nameZh: String
    let nameEn: String
    let primaryMuscle: MuscleGroup
    let setCount: Int
    let volumeKg: Double
    let bestWeightKg: Double?
    let bestReps: Int?
    let sets: [FeedSet]

    var id: String { nameEn }

    init(
        nameZh: String,
        nameEn: String,
        primaryMuscle: MuscleGroup,
        setCount: Int,
        volumeKg: Double,
        bestWeightKg: Double? = nil,
        bestReps: Int? = nil,
        sets: [FeedSet] = []
    ) {
        self.nameZh = nameZh
        self.nameEn = nameEn
        self.primaryMuscle = primaryMuscle
        self.setCount = setCount
        self.volumeKg = volumeKg
        self.bestWeightKg = bestWeightKg
        self.bestReps = bestReps
        self.sets = sets
    }

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
struct FeedItem: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let displayName: String
    var name: String
    let startedAt: Date
    let finishedAt: Date
    let exerciseCount: Int
    let setCount: Int
    let totalVolumeKg: Double
    let exercises: [FeedExerciseSummary]
    var likeCount: Int
    var likedByMe: Bool
    var commentCount: Int

    init(
        id: UUID = UUID(),
        userID: UUID,
        displayName: String,
        name: String,
        startedAt: Date,
        finishedAt: Date,
        exerciseCount: Int,
        setCount: Int,
        totalVolumeKg: Double,
        exercises: [FeedExerciseSummary] = [],
        likeCount: Int = 0,
        likedByMe: Bool = false,
        commentCount: Int = 0
    ) {
        self.id = id
        self.userID = userID
        self.displayName = displayName
        self.name = name
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.exerciseCount = exerciseCount
        self.setCount = setCount
        self.totalVolumeKg = totalVolumeKg
        self.exercises = exercises
        self.likeCount = likeCount
        self.likedByMe = likedByMe
        self.commentCount = commentCount
    }

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
        case commentCount = "comment_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userID = try c.decode(UUID.self, forKey: .userID)
        displayName = try c.decode(String.self, forKey: .displayName)
        name = try c.decode(String.self, forKey: .name)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        finishedAt = try c.decode(Date.self, forKey: .finishedAt)
        exerciseCount = try c.decode(Int.self, forKey: .exerciseCount)
        setCount = try c.decode(Int.self, forKey: .setCount)
        totalVolumeKg = try c.decode(Double.self, forKey: .totalVolumeKg)
        exercises = try c.decode([FeedExerciseSummary].self, forKey: .exercises)
        likeCount = try c.decode(Int.self, forKey: .likeCount)
        likedByMe = try c.decode(Bool.self, forKey: .likedByMe)
        commentCount = (try? c.decode(Int.self, forKey: .commentCount)) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userID, forKey: .userID)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(name, forKey: .name)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(finishedAt, forKey: .finishedAt)
        try container.encode(exerciseCount, forKey: .exerciseCount)
        try container.encode(setCount, forKey: .setCount)
        try container.encode(totalVolumeKg, forKey: .totalVolumeKg)
        try container.encode(exercises, forKey: .exercises)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encode(likedByMe, forKey: .likedByMe)
        try container.encode(commentCount, forKey: .commentCount)
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

    private var cacheKey: String { "feed_items_\(userID.uuidString)" }

    /// The signed-in viewer (used when pushing profile destinations).
    var viewerID: UUID { userID }

    init(userID: UUID) {
        self.userID = userID
        if let cached: [FeedItem] = DiskCache.load([FeedItem].self, key: "feed_items_\(userID.uuidString)") {
            self.items = cached
        } else {
            self.items = Self.sampleWorkouts(userID: userID)
        }
    }

    /// Loads the feed — everyone visible (nil), or one person's workouts
    /// (profile page). Visibility rules live inside the view either way.
    func load(filterUserID: UUID? = nil) async {
        isLoading = items.isEmpty
        defer { isLoading = false }

        do {
            let fetched: [FeedItem] = try await withThrowingTaskGroup(of: [FeedItem].self) { group in
                group.addTask {
                    if let filterUserID {
                        return try await self.client
                            .from("workout_feed")
                            .select()
                            .eq("user_id", value: filterUserID)
                            .limit(50)
                            .execute()
                            .value
                    } else {
                        return try await self.client
                            .from("workout_feed")
                            .select()
                            .limit(50)
                            .execute()
                            .value
                    }
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 2_500_000_000)
                    throw URLError(.timedOut)
                }
                guard let result = try await group.next() else {
                    throw URLError(.cannotParseResponse)
                }
                group.cancelAll()
                return result
            }

            if !fetched.isEmpty {
                self.items = fetched
                DiskCache.save(fetched, key: cacheKey)
            }
        } catch {
            if items.isEmpty {
                self.items = Self.sampleWorkouts(userID: filterUserID ?? userID)
            }
        }
    }

    static func sampleWorkouts(userID: UUID) -> [FeedItem] {
        let now = Date()
        return [
            FeedItem(
                id: UUID(),
                userID: userID,
                displayName: L10n.t("铁友 (你)", "Lifter (You)"),
                name: L10n.t("经典推力力量日", "Push Power & Strength"),
                startedAt: now.addingTimeInterval(-3600 * 24 * 1 - 3600),
                finishedAt: now.addingTimeInterval(-3600 * 24 * 1),
                exerciseCount: 3,
                setCount: 12,
                totalVolumeKg: 8_450,
                exercises: [
                    FeedExerciseSummary(
                        nameZh: "杠铃卧推",
                        nameEn: "Bench Press",
                        primaryMuscle: .chest,
                        setCount: 4,
                        volumeKg: 3_600,
                        bestWeightKg: 100.0,
                        bestReps: 5,
                        sets: [
                            FeedSet(weightKg: 60.0, reps: 10, isWarmup: true),
                            FeedSet(weightKg: 80.0, reps: 8),
                            FeedSet(weightKg: 95.0, reps: 6),
                            FeedSet(weightKg: 100.0, reps: 5)
                        ]
                    ),
                    FeedExerciseSummary(
                        nameZh: "杠铃过顶推举",
                        nameEn: "Overhead Press",
                        primaryMuscle: .shoulders,
                        setCount: 4,
                        volumeKg: 2_400,
                        bestWeightKg: 60.0,
                        bestReps: 6,
                        sets: [
                            FeedSet(weightKg: 40.0, reps: 10, isWarmup: true),
                            FeedSet(weightKg: 50.0, reps: 8),
                            FeedSet(weightKg: 55.0, reps: 6),
                            FeedSet(weightKg: 60.0, reps: 6)
                        ]
                    ),
                    FeedExerciseSummary(
                        nameZh: "双杠臂屈伸",
                        nameEn: "Dips",
                        primaryMuscle: .triceps,
                        setCount: 4,
                        volumeKg: 2_450,
                        bestWeightKg: 20.0,
                        bestReps: 8,
                        sets: [
                            FeedSet(weightKg: 0.0, reps: 12, isWarmup: true),
                            FeedSet(weightKg: 10.0, reps: 10),
                            FeedSet(weightKg: 15.0, reps: 8),
                            FeedSet(weightKg: 20.0, reps: 8)
                        ]
                    )
                ],
                likeCount: 5,
                likedByMe: true,
                commentCount: 2
            ),
            FeedItem(
                id: UUID(),
                userID: userID,
                displayName: L10n.t("铁友 (你)", "Lifter (You)"),
                name: L10n.t("背部厚度与拉力", "Pull Hypertrophy & Thickness"),
                startedAt: now.addingTimeInterval(-3600 * 24 * 3 - 3900),
                finishedAt: now.addingTimeInterval(-3600 * 24 * 3),
                exerciseCount: 3,
                setCount: 13,
                totalVolumeKg: 9_200,
                exercises: [
                    FeedExerciseSummary(
                        nameZh: "传统硬拉",
                        nameEn: "Deadlift",
                        primaryMuscle: .back,
                        setCount: 4,
                        volumeKg: 5_200,
                        bestWeightKg: 160.0,
                        bestReps: 4,
                        sets: [
                            FeedSet(weightKg: 100.0, reps: 8, isWarmup: true),
                            FeedSet(weightKg: 130.0, reps: 6),
                            FeedSet(weightKg: 150.0, reps: 5),
                            FeedSet(weightKg: 160.0, reps: 4)
                        ]
                    ),
                    FeedExerciseSummary(
                        nameZh: "杠铃俯身划船",
                        nameEn: "Barbell Row",
                        primaryMuscle: .back,
                        setCount: 4,
                        volumeKg: 2_600,
                        bestWeightKg: 80.0,
                        bestReps: 8,
                        sets: [
                            FeedSet(weightKg: 50.0, reps: 10, isWarmup: true),
                            FeedSet(weightKg: 65.0, reps: 8),
                            FeedSet(weightKg: 75.0, reps: 8),
                            FeedSet(weightKg: 80.0, reps: 8)
                        ]
                    ),
                    FeedExerciseSummary(
                        nameZh: "引体向上",
                        nameEn: "Pull-up",
                        primaryMuscle: .back,
                        setCount: 4,
                        volumeKg: 1_400,
                        bestWeightKg: 0.0,
                        bestReps: 10,
                        sets: [
                            FeedSet(weightKg: 0.0, reps: 10),
                            FeedSet(weightKg: 0.0, reps: 10),
                            FeedSet(weightKg: 0.0, reps: 8),
                            FeedSet(weightKg: 0.0, reps: 8)
                        ]
                    )
                ],
                likeCount: 8,
                likedByMe: false,
                commentCount: 4
            )
        ]
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

    // MARK: - Comments

    private struct CommentInsert: Encodable {
        let workout_id: UUID
        let user_id: UUID
        let display_name: String
        let body: String
    }

    /// Post a comment on a workout. Updates comment count optimistically.
    func postComment(workoutID: UUID, body: String, userID: UUID, displayName: String) async {
        guard let index = items.firstIndex(where: { $0.id == workoutID }) else { return }
        items[index].commentCount += 1
        do {
            try await client
                .from("workout_comments")
                .insert(CommentInsert(
                    workout_id: workoutID,
                    user_id: userID,
                    display_name: displayName,
                    body: body
                ))
                .execute()
        } catch {
            items[index].commentCount -= 1
        }
    }

    // MARK: - Workout Management

    /// Deletes a workout owned by the viewer from Supabase and removes it from the local list.
    func deleteWorkout(_ workoutID: UUID) async {
        items.removeAll { $0.id == workoutID }
        do {
            try await client
                .from("workouts")
                .delete()
                .eq("id", value: workoutID)
                .execute()
        } catch {
            errorMessage = L10n.t("删除训练失败", "Failed to delete workout")
        }
    }

    /// Renames a workout owned by the viewer and syncs local state.
    func updateWorkoutName(_ workoutID: UUID, name: String) async {
        guard let index = items.firstIndex(where: { $0.id == workoutID }) else { return }
        items[index].name = name
        do {
            struct NameUpdate: Encodable { let name: String }
            try await client
                .from("workouts")
                .update(NameUpdate(name: name))
                .eq("id", value: workoutID)
                .execute()
        } catch {
            // Error handling fallback
        }
    }
}
