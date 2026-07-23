import Foundation

/// Row in `public.workouts`. finishedAt == nil means the workout is live.
struct Workout: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    var name: String
    let startedAt: Date
    var finishedAt: Date?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case userID = "user_id"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
    }
}

/// Row in `public.workout_exercises` (exercise slot inside a workout).
struct WorkoutExercise: Identifiable, Codable, Hashable {
    let id: UUID
    let workoutID: UUID
    let exerciseID: UUID
    var orderIndex: Int
    var supersetGroup: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case workoutID = "workout_id"
        case exerciseID = "exercise_id"
        case orderIndex = "order_index"
        case supersetGroup = "superset_group"
    }
}

/// Row in `public.workout_sets`.
struct WorkoutSet: Identifiable, Codable, Hashable {
    let id: UUID
    let workoutExerciseID: UUID
    var setIndex: Int
    var weightKg: Double
    var reps: Int
    var rpe: Double?
    var isWarmup: Bool

    enum CodingKeys: String, CodingKey {
        case id, reps, rpe
        case workoutExerciseID = "workout_exercise_id"
        case setIndex = "set_index"
        case weightKg = "weight_kg"
        case isWarmup = "is_warmup"
    }

    /// Epley estimated 1RM. Warmup sets still get a value but are excluded
    /// from PR comparisons at the call site.
    var estimated1RM: Double {
        reps == 1 ? weightKg : weightKg * (1 + Double(reps) / 30)
    }

    var volume: Double { weightKg * Double(reps) }
}

/// Row in `public.personal_records`.
struct PersonalRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let exerciseID: UUID
    var weightKg: Double
    var reps: Int
    var estimated1RM: Double
    var workoutID: UUID?
    var achievedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, reps
        case userID = "user_id"
        case exerciseID = "exercise_id"
        case weightKg = "weight_kg"
        case estimated1RM = "estimated_1rm"
        case workoutID = "workout_id"
        case achievedAt = "achieved_at"
    }
}

/// Template with its exercise list, decoded as one nested query.
struct WorkoutTemplate: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    var name: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case userID = "user_id"
    }
}

struct WorkoutTemplateExercise: Identifiable, Codable, Hashable {
    let id: UUID
    let templateID: UUID
    let exerciseID: UUID
    var orderIndex: Int
    var supersetGroup: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case templateID = "template_id"
        case exerciseID = "exercise_id"
        case orderIndex = "order_index"
        case supersetGroup = "superset_group"
    }
}
