import Foundation
import Supabase

/// Computes which muscles were trained in a set of exercises, a workout,
/// or a date range — for feeding MuscleDiagramView.
@MainActor
final class MuscleActivationService {
    private let client = SupabaseService.client

    /// Muscles trained across all finished workouts in a date range.
    /// Counts every exercise that had at least one working (non-warmup) set.
    func musclesTrained(from startDate: Date, to endDate: Date,
                        library: ExerciseService) async -> Set<Muscle> {
        struct JoinedRow: Decodable {
            let exercise_id: UUID
            let workouts: WorkoutDate
            let workout_sets: [SetRow]

            struct WorkoutDate: Decodable { let finished_at: Date? }
            struct SetRow: Decodable { let is_warmup: Bool }
        }

        await library.loadIfNeeded()
        let formatter = ISO8601DateFormatter()

        do {
            let rows: [JoinedRow] = try await client
                .from("workout_exercises")
                .select("exercise_id, workouts!inner(finished_at), workout_sets(is_warmup)")
                .not("workouts.finished_at", operator: .is, value: "null")
                .gte("workouts.finished_at", value: formatter.string(from: startDate))
                .lte("workouts.finished_at", value: formatter.string(from: endDate))
                .execute()
                .value

            var result = Set<Muscle>()
            for row in rows where row.workout_sets.contains(where: { !$0.is_warmup }) {
                if let exercise = library.exercises.first(where: { $0.id == row.exercise_id }) {
                    result.formUnion(exercise.primaryMuscle.diagramMuscles)
                }
            }
            return result
        } catch {
            return []
        }
    }

    /// Muscles trained in the current ISO week (matches the weekly volume board).
    func musclesTrainedThisWeek(library: ExerciseService) async -> Set<Muscle> {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return await musclesTrained(from: weekStart, to: now, library: library)
    }

    /// Synchronous variant for an already-loaded workout (e.g. the summary
    /// screen): muscles from a WorkoutManager's completed exercises.
    func muscles(in activeExercises: [WorkoutManager.ActiveExercise]) -> Set<Muscle> {
        var result = Set<Muscle>()
        for ex in activeExercises where ex.sets.contains(where: { $0.isCompleted && !$0.isWarmup }) {
            result.formUnion(ex.exercise.primaryMuscle.diagramMuscles)
        }
        return result
    }
}
