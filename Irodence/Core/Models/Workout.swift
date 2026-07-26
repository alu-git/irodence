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
    /// nil for duration-mode sets (timed, no rep count).
    var reps: Int?
    /// Seconds held/performed; nil for rep-based sets.
    var durationSeconds: Int?
    var rpe: Double?
    var isWarmup: Bool

    enum CodingKeys: String, CodingKey {
        case id, reps, rpe
        case workoutExerciseID = "workout_exercise_id"
        case setIndex = "set_index"
        case weightKg = "weight_kg"
        case durationSeconds = "duration_seconds"
        case isWarmup = "is_warmup"
    }

    /// Tolerant decode: `duration_seconds` predates its migration in some
    /// environments — treat a missing column as nil rather than failing.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        workoutExerciseID = try c.decode(UUID.self, forKey: .workoutExerciseID)
        setIndex = try c.decode(Int.self, forKey: .setIndex)
        weightKg = try c.decode(Double.self, forKey: .weightKg)
        reps = try c.decodeIfPresent(Int.self, forKey: .reps)
        durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds)
        rpe = try c.decodeIfPresent(Double.self, forKey: .rpe)
        isWarmup = try c.decode(Bool.self, forKey: .isWarmup)
    }

    init(id: UUID, workoutExerciseID: UUID, setIndex: Int, weightKg: Double,
         reps: Int?, durationSeconds: Int? = nil, rpe: Double? = nil, isWarmup: Bool) {
        self.id = id
        self.workoutExerciseID = workoutExerciseID
        self.setIndex = setIndex
        self.weightKg = weightKg
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.rpe = rpe
        self.isWarmup = isWarmup
    }

    /// Epley estimated 1RM. Warmup sets still get a value but are excluded
    /// from PR comparisons at the call site. Rep-less (duration) sets have
    /// no 1RM equivalent and return 0.
    var estimated1RM: Double {
        guard let reps else { return 0 }
        return reps == 1 ? weightKg : weightKg * (1 + Double(reps) / 30)
    }

    var volume: Double { weightKg * Double(reps ?? 0) }
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
