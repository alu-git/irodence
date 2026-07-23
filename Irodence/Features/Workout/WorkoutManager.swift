import Foundation
import Supabase

/// State machine for the active (in-progress) workout.
///
/// Local draft state is source of truth for the UI; completed sets and added
/// exercises are written through to Supabase immediately so nothing is lost
/// if the app is killed mid-workout.
@MainActor
final class WorkoutManager: ObservableObject {

    /// A set as edited on screen. Text fields stay strings until validated.
    struct ActiveSet: Identifiable, Equatable {
        var id = UUID()          // local identity; dbID set once persisted
        var dbID: UUID?
        var weight = ""
        var reps = ""
        var rpe = ""
        var isWarmup = false
        var isCompleted = false
        // Previous-session placeholder values ("上次" column)
        var prevWeight: Double?
        var prevReps: Int?

        var parsedWeight: Double? { Double(weight.replacingOccurrences(of: ",", with: ".")) }
        var parsedReps: Int? { Int(reps) }
        var parsedRPE: Double? { rpe.isEmpty ? nil : Double(rpe) }
        var isValid: Bool { parsedWeight != nil && parsedReps != nil && (parsedWeight ?? -1) >= 0 && (parsedReps ?? 0) > 0 }
    }

    struct ActiveExercise: Identifiable, Equatable {
        var id = UUID()          // local identity
        var dbID: UUID?
        let exercise: Exercise
        var supersetGroup: Int?
        var sets: [ActiveSet]
        var previousSets: [WorkoutSet] = []
    }

    struct PRResult: Identifiable, Equatable {
        var id: UUID { exercise.id }
        let exercise: Exercise
        let weightKg: Double
        let reps: Int
        let estimated1RM: Double
    }

    @Published private(set) var workoutID: UUID?
    @Published var name = "训练"
    @Published var exercises: [ActiveExercise] = []
    @Published private(set) var startedAt: Date?
    @Published var restEndsAt: Date?
    @Published var restDurationSeconds: TimeInterval = 120
    @Published private(set) var summary: Summary?

    /// Clears the shown post-workout summary (called on sheet dismissal).
    func clearSummary() { summary = nil }
    @Published var errorMessage: String?

    private let service = WorkoutService()
    private let userID: UUID

    /// Exposed so views can load this user's templates.
    var userIDForTemplates: UUID { userID }

    init(userID: UUID) {
        self.userID = userID
    }

    var isActive: Bool { workoutID != nil }

    // MARK: - Lifecycle

    func startEmpty() async {
        await start(name: "自由训练", exercises: [])
    }

    func start(from template: WorkoutTemplate,
               templateExercises: [WorkoutTemplateExercise],
               library: ExerciseService) async {
        let resolved = templateExercises.compactMap { te -> (Exercise, Int?)? in
            guard let ex = library.exercises.first(where: { $0.id == te.exerciseID }) else { return nil }
            return (ex, te.supersetGroup)
        }
        await start(name: template.name, exercises: resolved)
    }

    private func start(name: String, exercises: [(Exercise, Int?)]) async {
        errorMessage = nil
        do {
            let workout = try await service.createWorkout(userID: userID, name: name)
            workoutID = workout.id
            self.name = name
            startedAt = workout.startedAt
            summary = nil
            self.exercises = []
            for (index, item) in exercises.enumerated() {
                await addExercise(item.0, supersetGroup: item.1, orderIndex: index)
                // Templates start with 3 empty sets per exercise
                if let last = self.exercises.indices.last {
                    for _ in 0..<3 { addSet(to: last) }
                }
            }
        } catch {
            errorMessage = "开始训练失败，请检查网络"
        }
    }

    /// Discards the active workout without finishing. Hard-deletes the row.
    func discard() async {
        guard let id = workoutID else { return }
        do { try await service.discardWorkout(id) } catch { /* row may linger; acceptable */ }
        reset()
    }

    private func reset() {
        workoutID = nil
        exercises = []
        startedAt = nil
        restEndsAt = nil
        name = "训练"
    }

    // MARK: - Exercises

    func addExercise(_ exercise: Exercise, supersetGroup: Int? = nil,
                     orderIndex: Int? = nil) async {
        guard let workoutID else { return }
        let index = orderIndex ?? exercises.count
        do {
            let row = try await service.addExercise(
                workoutID: workoutID, exerciseID: exercise.id,
                orderIndex: index, supersetGroup: supersetGroup
            )
            let previous = (try? await service.fetchPreviousSets(exerciseID: exercise.id)) ?? []
            exercises.append(ActiveExercise(
                dbID: row.id, exercise: exercise,
                supersetGroup: supersetGroup,
                sets: [makeSet(previous: previous.first)],
                previousSets: previous
            ))
        } catch {
            errorMessage = "添加动作失败"
        }
    }

    func removeExercise(at index: Int) async {
        guard exercises.indices.contains(index) else { return }
        let ex = exercises[index]
        exercises.remove(at: index)
        if let dbID = ex.dbID {
            do { try await service.removeExercise(dbID) } catch { errorMessage = "删除动作失败" }
        }
    }

    /// Groups the exercise at `index` with the previous one as a superset.
    func supersetWithPrevious(at index: Int) async {
        guard index > 0, exercises.indices.contains(index) else { return }
        let group = exercises[index - 1].supersetGroup
            ?? ((exercises.compactMap(\.supersetGroup).max() ?? 0) + 1)
        exercises[index - 1].supersetGroup = group
        exercises[index].supersetGroup = group
        for i in [index - 1, index] {
            if let dbID = exercises[i].dbID {
                try? await service.updateSupersetGroup(dbID, group: group)
            }
        }
    }

    func removeFromSuperset(at index: Int) async {
        guard exercises.indices.contains(index) else { return }
        exercises[index].supersetGroup = nil
        if let dbID = exercises[index].dbID {
            try? await service.updateSupersetGroup(dbID, group: nil)
        }
    }

    // MARK: - Sets

    private func makeSet(previous: WorkoutSet?) -> ActiveSet {
        var set = ActiveSet()
        set.prevWeight = previous?.weightKg
        set.prevReps = previous?.reps
        return set
    }

    func addSet(to exerciseIndex: Int) {
        guard exercises.indices.contains(exerciseIndex) else { return }
        let ex = exercises[exerciseIndex]
        // Placeholder: same-index set from last session, else copy current last set
        let prev = ex.previousSets.count > ex.sets.count ? ex.previousSets[ex.sets.count] : nil
        var set = makeSet(previous: prev)
        if prev == nil, let last = ex.sets.last {
            set.weight = last.weight
            set.reps = last.reps
        }
        exercises[exerciseIndex].sets.append(set)
    }

    func deleteSet(exerciseIndex: Int, setID: UUID) async {
        guard exercises.indices.contains(exerciseIndex),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }
        let set = exercises[exerciseIndex].sets[setIndex]
        exercises[exerciseIndex].sets.remove(at: setIndex)
        if let dbID = set.dbID {
            try? await service.deleteSet(dbID)
        }
    }

    /// Marks a set done and writes it through. Starts the rest timer.
    func completeSet(exerciseIndex: Int, setID: UUID) async {
        guard exercises.indices.contains(exerciseIndex),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }
        var set = exercises[exerciseIndex].sets[setIndex]
        guard set.isValid, let weight = set.parsedWeight, let reps = set.parsedReps else {
            errorMessage = "请填写有效的重量和次数"
            return
        }
        guard let exerciseDBID = exercises[exerciseIndex].dbID else { return }

        do {
            let row = try await service.addSet(.init(
                workout_exercise_id: exerciseDBID,
                set_index: setIndex,
                weight_kg: weight,
                reps: reps,
                rpe: set.parsedRPE,
                is_warmup: set.isWarmup
            ))
            set.dbID = row.id
            set.isCompleted = true
            exercises[exerciseIndex].sets[setIndex] = set
            restEndsAt = Date().addingTimeInterval(restDurationSeconds)
        } catch {
            errorMessage = "保存组失败"
        }
    }

    func toggleWarmup(exerciseIndex: Int, setID: UUID) async {
        guard exercises.indices.contains(exerciseIndex),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }
        exercises[exerciseIndex].sets[setIndex].isWarmup.toggle()
        // Warmup flag changes persist only for completed sets
        let set = exercises[exerciseIndex].sets[setIndex]
        if set.isCompleted, let dbID = set.dbID,
           let weight = set.parsedWeight, let reps = set.parsedReps {
            try? await service.updateSet(dbID, .init(
                weight_kg: weight, reps: reps, rpe: set.parsedRPE, is_warmup: set.isWarmup
            ))
        }
    }

    // MARK: - Finish

    struct Summary: Equatable {
        let name: String
        let duration: TimeInterval
        let totalVolumeKg: Double
        let completedSets: Int
        let prs: [PRResult]
    }

    /// Finishes the workout: stamps finished_at, computes volume + PRs.
    /// Returns false if nothing was logged (offer discard instead).
    @discardableResult
    func finish() async -> Bool {
        guard let id = workoutID, let startedAt else { return false }
        let completed = exercises.flatMap(\.sets).filter(\.isCompleted)
        guard !completed.isEmpty else { return false }

        do {
            try await service.finishWorkout(id, name: name)

            let volume = exercises.flatMap { ex in
                ex.sets.filter { $0.isCompleted && !$0.isWarmup }.compactMap { s in
                    (s.parsedWeight ?? 0) * Double(s.parsedReps ?? 0)
                }
            }.reduce(0, +)

            let prs = await detectAndSavePRs(workoutID: id)

            summary = Summary(
                name: name,
                duration: Date().timeIntervalSince(startedAt),
                totalVolumeKg: volume,
                completedSets: completed.count,
                prs: prs
            )
            reset()
            return true
        } catch {
            errorMessage = "保存训练失败，请重试"
            return false
        }
    }

    /// Compares each exercise's best est. 1RM (Epley) this session against
    /// stored PRs and inserts new records.
    private func detectAndSavePRs(workoutID: UUID) async -> [PRResult] {
        let current = (try? await service.fetchCurrentPRs(userID: userID)) ?? [:]
        var results: [PRResult] = []

        for ex in exercises {
            let workingSets = ex.sets.filter { $0.isCompleted && !$0.isWarmup && $0.isValid }
            guard let best = workingSets.max(by: {
                ($0.parsedWeight ?? 0) * (1 + Double($0.parsedReps ?? 0) / 30)
                    < ($1.parsedWeight ?? 0) * (1 + Double($1.parsedReps ?? 0) / 30)
            }), let weight = best.parsedWeight, let reps = best.parsedReps
            else { continue }

            let est1RM = reps == 1 ? weight : weight * (1 + Double(reps) / 30)
            guard est1RM > (current[ex.exercise.id] ?? 0) else { continue }

            do {
                try await service.insertPR(.init(
                    user_id: userID, exercise_id: ex.exercise.id,
                    weight_kg: weight, reps: reps,
                    estimated_1rm: est1RM, workout_id: workoutID
                ))
                results.append(PRResult(exercise: ex.exercise, weightKg: weight,
                                        reps: reps, estimated1RM: est1RM))
            } catch { /* PR save failure shouldn't block the summary */ }
        }
        return results
    }

    // MARK: - Templates

    func saveAsTemplate(templateName: String) async {
        guard !exercises.isEmpty else { return }
        do {
            try await service.createTemplate(
                userID: userID, name: templateName,
                exercises: exercises.map { ($0.exercise.id, $0.supersetGroup) }
            )
        } catch {
            errorMessage = "保存模板失败"
        }
    }
}
