import Foundation
import Supabase

/// All workout-related Supabase I/O. Local logging state lives in
/// WorkoutManager; this service is the write-through + query layer.
/// Stateless, so it stays non-isolated and callers can fire requests in
/// parallel from task groups.
final class WorkoutService: Sendable {
    private let client = SupabaseService.client

    // MARK: - Workout lifecycle

    struct WorkoutInsert: Encodable {
        let user_id: UUID
        let name: String
    }

    func createWorkout(userID: UUID, name: String) async throws -> Workout {
        try await client
            .from("workouts")
            .insert(WorkoutInsert(user_id: userID, name: name))
            .select()
            .single()
            .execute()
            .value
    }

    struct FinishUpdate: Encodable {
        let finished_at: Date
        let name: String
    }

    func finishWorkout(_ workoutID: UUID, name: String) async throws {
        try await client
            .from("workouts")
            .update(FinishUpdate(finished_at: Date(), name: name))
            .eq("id", value: workoutID)
            .execute()
    }

    /// Hard-deletes a discarded (unfinished) workout; sets cascade away.
    func discardWorkout(_ workoutID: UUID) async throws {
        try await client
            .from("workouts")
            .delete()
            .eq("id", value: workoutID)
            .execute()
    }

    // MARK: - Exercises within a workout

    struct WorkoutExerciseInsert: Encodable {
        let workout_id: UUID
        let exercise_id: UUID
        let order_index: Int
        let superset_group: Int?
    }

    func addExercise(workoutID: UUID, exerciseID: UUID, orderIndex: Int,
                     supersetGroup: Int? = nil) async throws -> WorkoutExercise {
        try await client
            .from("workout_exercises")
            .insert(WorkoutExerciseInsert(
                workout_id: workoutID, exercise_id: exerciseID,
                order_index: orderIndex, superset_group: supersetGroup
            ))
            .select()
            .single()
            .execute()
            .value
    }

    struct SupersetUpdate: Encodable {
        let superset_group: Int?
    }

    func updateSupersetGroup(_ workoutExerciseID: UUID, group: Int?) async throws {
        try await client
            .from("workout_exercises")
            .update(SupersetUpdate(superset_group: group))
            .eq("id", value: workoutExerciseID)
            .execute()
    }

    func removeExercise(_ workoutExerciseID: UUID) async throws {
        try await client
            .from("workout_exercises")
            .delete()
            .eq("id", value: workoutExerciseID)
            .execute()
    }

    // MARK: - Sets

    struct SetInsert: Encodable {
        let workout_exercise_id: UUID
        let set_index: Int
        let weight_kg: Double
        let reps: Int?
        let duration_seconds: Int?
        let rpe: Double?
        let is_warmup: Bool
    }

    func addSet(_ set: SetInsert) async throws -> WorkoutSet {
        try await client
            .from("workout_sets")
            .insert(set)
            .select()
            .single()
            .execute()
            .value
    }

    struct SetUpdate: Encodable {
        let weight_kg: Double
        let reps: Int?
        let duration_seconds: Int?
        let rpe: Double?
        let is_warmup: Bool
    }

    func updateSet(_ setID: UUID, _ update: SetUpdate) async throws {
        try await client
            .from("workout_sets")
            .update(update)
            .eq("id", value: setID)
            .execute()
    }

    func deleteSet(_ setID: UUID) async throws {
        try await client
            .from("workout_sets")
            .delete()
            .eq("id", value: setID)
            .execute()
    }

    /// Sets from the user's most recent session containing this exercise —
    /// used to pre-fill placeholders ("上次" column).
    func fetchPreviousSets(exerciseID: UUID) async throws -> [WorkoutSet] {
        struct JoinedRow: Decodable {
            let id: UUID
            let workout_id: UUID
            let workouts: WorkoutDate
            let workout_sets: [WorkoutSet]

            struct WorkoutDate: Decodable {
                let finished_at: Date?
            }
        }

        let rows: [JoinedRow] = try await client
            .from("workout_exercises")
            .select("id, workout_id, workouts!inner(finished_at), workout_sets(*)")
            .eq("exercise_id", value: exerciseID)
            .not("workouts.finished_at", operator: .is, value: "null")
            .order("finished_at", ascending: false, referencedTable: "workouts")
            .limit(1)
            .execute()
            .value

        return rows.first?.workout_sets.sorted(by: { $0.setIndex < $1.setIndex }) ?? []
    }

    // MARK: - Personal records

    /// Current best est. 1RM per exercise for the user (for PR comparison).
    func fetchCurrentPRs(userID: UUID) async throws -> [UUID: Double] {
        let rows: [PersonalRecord] = try await client
            .from("personal_records")
            .select()
            .eq("user_id", value: userID)
            .execute()
            .value

        var best: [UUID: Double] = [:]
        for row in rows {
            best[row.exerciseID] = max(best[row.exerciseID] ?? 0, row.estimated1RM)
        }
        return best
    }

    struct PRInsert: Encodable {
        let user_id: UUID
        let exercise_id: UUID
        let weight_kg: Double
        let reps: Int
        let estimated_1rm: Double
        let workout_id: UUID
    }

    func insertPR(_ pr: PRInsert) async throws {
        try await client
            .from("personal_records")
            .insert(pr)
            .execute()
    }

    // MARK: - Templates

    func fetchTemplates(userID: UUID) async throws -> [(template: WorkoutTemplate, exercises: [WorkoutTemplateExercise])] {
        struct JoinedTemplate: Decodable {
            let id: UUID
            let user_id: UUID
            let name: String
            let workout_template_exercises: [WorkoutTemplateExercise]
        }

        let rows: [JoinedTemplate] = try await client
            .from("workout_templates")
            .select("id, user_id, name, workout_template_exercises(*)")
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .execute()
            .value

        return rows.map {
            (
                WorkoutTemplate(id: $0.id, userID: $0.user_id, name: $0.name),
                $0.workout_template_exercises.sorted { $0.orderIndex < $1.orderIndex }
            )
        }
    }

    struct TemplateInsert: Encodable {
        let user_id: UUID
        let name: String
    }

    struct TemplateExerciseInsert: Encodable {
        let template_id: UUID
        let exercise_id: UUID
        let order_index: Int
        let superset_group: Int?
    }

    func createTemplate(userID: UUID, name: String,
                        exercises: [(exerciseID: UUID, supersetGroup: Int?)]) async throws {
        let template: WorkoutTemplate = try await client
            .from("workout_templates")
            .insert(TemplateInsert(user_id: userID, name: name))
            .select()
            .single()
            .execute()
            .value

        let rows = exercises.enumerated().map { index, item in
            TemplateExerciseInsert(
                template_id: template.id,
                exercise_id: item.exerciseID,
                order_index: index,
                superset_group: item.supersetGroup
            )
        }
        if !rows.isEmpty {
            try await client
                .from("workout_template_exercises")
                .insert(rows)
                .execute()
        }
    }

    func deleteTemplate(_ templateID: UUID) async throws {
        try await client
            .from("workout_templates")
            .delete()
            .eq("id", value: templateID)
            .execute()
    }
}
