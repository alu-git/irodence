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
        /// Duration in seconds as typed (duration-mode sets only).
        var duration = ""
        var rpe = ""
        var isWarmup = false
        var isCompleted = false
        /// Non-nil while the per-set stopwatch is running (duration mode).
        var timerStartedAt: Date?
        /// Set when the background write-through failed (offline/slow
        /// network); the row shows a retry affordance.
        var syncFailed = false
        // Previous-session placeholder values ("上次" column)
        var prevWeight: Double?
        var prevReps: Int?
        var prevDuration: Int?

        var parsedWeight: Double? { Double(weight.replacingOccurrences(of: ",", with: ".")) }
        var parsedReps: Int? { Int(reps) }
        var parsedRPE: Double? { rpe.isEmpty ? nil : Double(rpe) }
        /// Accepts plain seconds ("90") or mm:ss ("1:30").
        var parsedDuration: Int? { Self.parseDuration(duration) }

        static func parseDuration(_ text: String) -> Int? {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            if let seconds = Int(trimmed) { return seconds > 0 ? seconds : nil }
            let parts = trimmed.split(separator: ":")
            guard parts.count == 2,
                  let minutes = Int(parts[0]), let seconds = Int(parts[1]),
                  minutes >= 0, seconds >= 0, seconds < 60 else { return nil }
            let total = minutes * 60 + seconds
            return total > 0 ? total : nil
        }

        /// 90 -> "1:30", 45 -> "0:45"
        static func formatDuration(_ seconds: Int) -> String {
            String(format: "%d:%02d", seconds / 60, seconds % 60)
        }

        func isValid(for mode: TrackingMode) -> Bool {
            switch mode {
            case .weighted:
                return parsedWeight != nil && parsedReps != nil
                    && (parsedWeight ?? -1) >= 0 && (parsedReps ?? 0) > 0
            case .bodyweight:
                return (parsedReps ?? 0) > 0
            case .duration:
                return parsedDuration != nil
            }
        }
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
        /// Pre-session best est. 1RM for this exercise (nil = first record).
        let previousBest1RM: Double?

        /// Improvement over the previous record, nil for first-time records.
        var deltaKg: Double? {
            previousBest1RM.map { estimated1RM - $0 }
        }
    }

    @Published private(set) var workoutID: UUID?
    @Published var name = "训练"
    @Published var exercises: [ActiveExercise] = []
    @Published private(set) var startedAt: Date?
    @Published var restEndsAt: Date?
    /// Default rest between sets; persisted so the profile-page setting and
    /// the timer's gear menu stay in sync across launches.
    @Published var restDurationSeconds: TimeInterval {
        didSet { UserDefaults.standard.set(restDurationSeconds, forKey: Self.restDurationKey) }
    }
    static let restDurationKey = "restDurationSeconds"
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
        let saved = UserDefaults.standard.double(forKey: Self.restDurationKey)
        restDurationSeconds = saved > 0 ? saved : 120
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

    /// Starts a workout from a built-in template, resolving its exercise
    /// names against the loaded library. Names that don't match (e.g. a
    /// seed not yet applied) are skipped silently.
    func startBuiltIn(_ template: BuiltInTemplate, library: ExerciseService) async {
        let resolved = template.items.compactMap { item -> (Exercise, Int?)? in
            guard let ex = library.exercises.first(where: { $0.nameEn == item.nameEn }) else { return nil }
            return (ex, item.supersetGroup)
        }
        guard !resolved.isEmpty else {
            errorMessage = "模板动作尚未同步，请下拉刷新动作库"
            return
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

            // Insert every exercise + fetch its previous-session sets in
            // PARALLEL — sequentially this is 2 round trips per exercise,
            // which dominates template start time on high-latency networks.
            // A failed exercise is dropped rather than aborting the start.
            typealias Prepared = (index: Int, row: WorkoutExercise?, previous: [WorkoutSet])
            let prepared: [Prepared] = await withTaskGroup(of: Prepared.self) { group in
                for (index, item) in exercises.enumerated() {
                    group.addTask { [service] in
                        do {
                            let row = try await service.addExercise(
                                workoutID: workout.id, exerciseID: item.0.id,
                                orderIndex: index, supersetGroup: item.1
                            )
                            let previous = (try? await service.fetchPreviousSets(exerciseID: item.0.id)) ?? []
                            return (index, row, previous)
                        } catch {
                            return (index, nil, [])
                        }
                    }
                }
                var results: [Prepared] = []
                for await result in group { results.append(result) }
                return results
            }

            self.exercises = prepared
                .sorted { $0.index < $1.index }
                .compactMap { index, row, previous in
                    guard let row else { return nil }
                    let mode = exercises[index].0.trackingMode
                    // Templates start with 3 empty sets per exercise,
                    // each with its same-index previous set as placeholder
                    let sets = (0..<3).map { setIndex in
                        makeSet(previous: previous.count > setIndex ? previous[setIndex] : nil,
                                mode: mode)
                    }
                    return ActiveExercise(
                        dbID: row.id, exercise: exercises[index].0,
                        supersetGroup: exercises[index].1,
                        sets: sets, previousSets: previous
                    )
                }

            if self.exercises.count < exercises.count {
                errorMessage = "部分动作添加失败，请检查网络"
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
                sets: [makeSet(previous: previous.first, mode: exercise.trackingMode)],
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

    /// New set, Hevy-style autofilled with the same-index set from the last
    /// session: values land in the text fields as editable values (also kept
    /// as prev* placeholders for the "上次" column), so the user can just tap
    /// ✓ when repeating a set. Only the fields the tracking mode uses are
    /// filled — bodyweight gets reps, duration gets seconds.
    private func makeSet(previous: WorkoutSet?, mode: TrackingMode) -> ActiveSet {
        var set = ActiveSet()
        set.prevWeight = previous?.weightKg
        set.prevReps = previous?.reps
        set.prevDuration = previous?.durationSeconds
        switch mode {
        case .weighted:
            if let weight = previous?.weightKg {
                set.weight = Self.formatKg(weight)
            }
            if let reps = previous?.reps {
                set.reps = String(reps)
            }
        case .bodyweight:
            if let reps = previous?.reps {
                set.reps = String(reps)
            }
        case .duration:
            if let seconds = previous?.durationSeconds {
                set.duration = ActiveSet.formatDuration(seconds)
            }
        }
        return set
    }

    /// 60.0 -> "60", 22.5 -> "22.5" (no trailing ".0" in the text field).
    static func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    func addSet(to exerciseIndex: Int) {
        guard exercises.indices.contains(exerciseIndex) else { return }
        let ex = exercises[exerciseIndex]
        // Autofill: same-index set from last session, else copy current last set
        let prev = ex.previousSets.count > ex.sets.count ? ex.previousSets[ex.sets.count] : nil
        var set = makeSet(previous: prev, mode: ex.exercise.trackingMode)
        if prev == nil, let last = ex.sets.last {
            set.weight = last.weight
            set.reps = last.reps
            set.duration = last.duration
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

    /// Marks a set done INSTANTLY (checkmark + rest timer), then writes it
    /// through in the background. A failed write flags the set for retry
    /// instead of blocking the UI.
    func completeSet(exerciseIndex: Int, setID: UUID) {
        guard exercises.indices.contains(exerciseIndex),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }
        let mode = exercises[exerciseIndex].exercise.trackingMode
        var set = exercises[exerciseIndex].sets[setIndex]

        // Completing with the stopwatch still running stops it and logs
        // the elapsed time as the set's duration.
        if mode == .duration, let timerStart = set.timerStartedAt {
            set.duration = ActiveSet.formatDuration(max(1, Int(Date().timeIntervalSince(timerStart))))
            set.timerStartedAt = nil
        }

        guard set.isValid(for: mode) else {
            switch mode {
            case .weighted: errorMessage = "请填写有效的重量和次数"
            case .bodyweight: errorMessage = "请填写有效的次数"
            case .duration: errorMessage = "请填写有效的时长（秒或 分:秒）"
            }
            return
        }
        guard let exerciseDBID = exercises[exerciseIndex].dbID else { return }

        set.isCompleted = true
        set.syncFailed = false
        exercises[exerciseIndex].sets[setIndex] = set
        restEndsAt = Date().addingTimeInterval(restDurationSeconds)

        Task { await persistSet(exerciseDBID: exerciseDBID, setID: setID) }
    }

    /// Starts/stops the per-set stopwatch (duration-mode exercises: planks,
    /// cardio). Stopping writes the elapsed time into the duration field.
    func toggleSetTimer(exerciseIndex: Int, setID: UUID) {
        guard exercises.indices.contains(exerciseIndex),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }
        var set = exercises[exerciseIndex].sets[setIndex]
        if let started = set.timerStartedAt {
            set.duration = ActiveSet.formatDuration(max(1, Int(Date().timeIntervalSince(started))))
            set.timerStartedAt = nil
        } else {
            set.timerStartedAt = Date()
        }
        exercises[exerciseIndex].sets[setIndex] = set
    }

    /// Retries the background write for a set flagged as failed.
    func retrySetSync(exerciseIndex: Int, setID: UUID) async {
        guard exercises.indices.contains(exerciseIndex),
              let exerciseDBID = exercises[exerciseIndex].dbID,
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }
        exercises[exerciseIndex].sets[setIndex].syncFailed = false
        await persistSet(exerciseDBID: exerciseDBID, setID: setID)
    }

    /// Background write-through for one completed set. Re-looks-up indices
    /// by ID since the arrays may have shifted since the tap.
    private func persistSet(exerciseDBID: UUID, setID: UUID) async {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.dbID == exerciseDBID }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }
        let mode = exercises[exerciseIndex].exercise.trackingMode
        let set = exercises[exerciseIndex].sets[setIndex]
        guard set.isValid(for: mode) else { return }

        do {
            let row = try await service.addSet(.init(
                workout_exercise_id: exerciseDBID,
                set_index: setIndex,
                weight_kg: mode.usesWeight ? (set.parsedWeight ?? 0) : 0,
                reps: mode.usesReps ? set.parsedReps : nil,
                duration_seconds: mode == .duration ? set.parsedDuration : nil,
                rpe: set.parsedRPE,
                is_warmup: set.isWarmup
            ))
            exercises[exerciseIndex].sets[setIndex].dbID = row.id
            exercises[exerciseIndex].sets[setIndex].syncFailed = false
        } catch {
            exercises[exerciseIndex].sets[setIndex].syncFailed = true
        }
    }

    func toggleWarmup(exerciseIndex: Int, setID: UUID) async {
        guard exercises.indices.contains(exerciseIndex),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }
        exercises[exerciseIndex].sets[setIndex].isWarmup.toggle()
        // Warmup flag changes persist only for completed sets
        let mode = exercises[exerciseIndex].exercise.trackingMode
        let set = exercises[exerciseIndex].sets[setIndex]
        if set.isCompleted, let dbID = set.dbID, set.isValid(for: mode) {
            try? await service.updateSet(dbID, .init(
                weight_kg: mode.usesWeight ? (set.parsedWeight ?? 0) : 0,
                reps: mode.usesReps ? set.parsedReps : nil,
                duration_seconds: mode == .duration ? set.parsedDuration : nil,
                rpe: set.parsedRPE, is_warmup: set.isWarmup
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
        /// Best DOTS score across this session's lifts (nil without
        /// sex/bodyweight on the profile).
        let dotsScore: Double?
        /// dotsScore minus the rolling average of recent sessions.
        let dotsDelta: Double?
        /// Consecutive training weeks including this one (0 when unknown).
        let streakWeeks: Int
        /// Core lift that moved closest to the next strength tier.
        let tierMoment: TierMoment?
    }

    /// Tier progress for the lift that gained the most ground this session.
    struct TierMoment: Equatable {
        let lift: CoreLift
        let tier: StrengthTier
        let nextTier: StrengthTier?
        let progressBefore: Double
        let progressAfter: Double
        /// DOTS still needed for the next tier (nil at elite).
        let dotsToNext: Double?
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

            let prOutcome = await detectAndSavePRs(workoutID: id)
            let context = await buildRewardContext(
                workoutID: id, preSessionBests: prOutcome.preSessionBests)

            summary = Summary(
                name: name,
                duration: Date().timeIntervalSince(startedAt),
                totalVolumeKg: volume,
                completedSets: completed.count,
                prs: prOutcome.prs,
                dotsScore: context.dots,
                dotsDelta: context.delta,
                streakWeeks: context.streak,
                tierMoment: context.tier
            )
            reset()
            return true
        } catch {
            errorMessage = "保存训练失败，请重试"
            return false
        }
    }

    /// Compares each exercise's best est. 1RM (Epley) this session against
    /// stored PRs and inserts new records. Also returns the pre-session
    /// bests so the reward context can measure tier progress without a
    /// second fetch.
    private func detectAndSavePRs(workoutID: UUID) async
        -> (prs: [PRResult], preSessionBests: [UUID: Double])
    {
        let current = (try? await service.fetchCurrentPRs(userID: userID)) ?? [:]
        var results: [PRResult] = []

        for ex in exercises {
            // 1RM-based PRs only make sense for weighted sets
            guard ex.exercise.trackingMode == .weighted else { continue }
            let workingSets = ex.sets.filter { $0.isCompleted && !$0.isWarmup && $0.isValid(for: .weighted) }
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
                                        reps: reps, estimated1RM: est1RM,
                                        previousBest1RM: current[ex.exercise.id]))
            } catch { /* PR save failure shouldn't block the summary */ }
        }
        return (results, current)
    }

    /// Best-effort data for the summary's reward moment: session DOTS and
    /// its delta vs. recent sessions, the weekly streak, and tier progress.
    /// Everything degrades to nil/0 on network failure — the base stats and
    /// PRs are already in hand and always render.
    private func buildRewardContext(workoutID: UUID, preSessionBests: [UUID: Double]) async
        -> (dots: Double?, delta: Double?, streak: Int, tier: TierMoment?)
    {
        let inputs = try? await service.fetchStrengthInputs(userID: userID)
        guard let sex = inputs?.sex, let bodyweight = inputs?.bodyweightKg, bodyweight > 0 else {
            // Streak doesn't need DOTS inputs — still try to show it.
            let streak = await computeStreak()
            return (nil, nil, streak, nil)
        }

        func dots(_ liftedKg: Double) -> Double {
            DOTSCalculator.score(liftedKg: liftedKg, bodyweightKg: bodyweight, sex: sex)
        }

        // Session best est-1RM per exercise, from local logging state.
        var sessionBests: [UUID: (exercise: Exercise, est1RM: Double)] = [:]
        for ex in exercises where ex.exercise.trackingMode == .weighted {
            let best = ex.sets
                .filter { $0.isCompleted && !$0.isWarmup && $0.isValid(for: .weighted) }
                .map { s -> Double in
                    let w = s.parsedWeight ?? 0, r = Double(s.parsedReps ?? 0)
                    return r == 1 ? w : w * (1 + r / 30)
                }
                .max() ?? 0
            if best > 0 { sessionBests[ex.exercise.id] = (ex.exercise, best) }
        }

        let sessionDots = sessionBests.values.map { dots($0.est1RM) }.max()

        // Delta vs. the rolling average of the last 8 weeks' sessions.
        var delta: Double?
        if let sessionDots,
           let recent = try? await service.fetchRecentSessionBests(
               userID: userID, since: Date().addingTimeInterval(-56 * 86_400)) {
            let priorDots = recent
                .filter { $0.workoutID != workoutID }
                .map { dots($0.bestEst1RM) }
            if !priorDots.isEmpty {
                delta = sessionDots - priorDots.reduce(0, +) / Double(priorDots.count)
            }
        }

        let streak = await computeStreak()

        // Tier moment: among core lifts performed this session, the one that
        // gained the most progress toward its next tier.
        var moment: TierMoment?
        var bestGain = -Double.infinity
        for lift in CoreLift.allCases {
            guard let session = sessionBests.values.first(where: {
                $0.exercise.nameEn == lift.exerciseNameEn
            }) else { continue }
            let before = preSessionBests[session.exercise.id] ?? 0
            let after = max(before, session.est1RM)
            let beforeStanding = StrengthStandards.progressToNextTier(
                dots: dots(before), lift: lift, sex: sex)
            let afterStanding = StrengthStandards.progressToNextTier(
                dots: dots(after), lift: lift, sex: sex)
            // Crossing a tier boundary counts as a full bar's worth of gain.
            let gain = Double(afterStanding.tier.rawValue) + afterStanding.progress
                     - Double(beforeStanding.tier.rawValue) - beforeStanding.progress
            if gain > bestGain {
                bestGain = gain
                moment = TierMoment(
                    lift: lift,
                    tier: afterStanding.tier,
                    nextTier: StrengthTier(rawValue: afterStanding.tier.rawValue + 1),
                    progressBefore: beforeStanding.progress,
                    progressAfter: afterStanding.progress,
                    dotsToNext: afterStanding.nextBoundary.map { $0 - dots(after) }
                )
            }
        }

        return (sessionDots, delta, streak, moment)
    }

    /// Consecutive calendar weeks with ≥1 finished workout, counting back
    /// from this week. Returns 0 if the history can't be loaded.
    private func computeStreak() async -> Int {
        guard let dates = try? await service.fetchWorkoutDates(
            userID: userID, since: Date().addingTimeInterval(-366 * 86_400)
        ) else { return 0 }

        let calendar = Calendar.current
        var weeks = Set<Date>()
        for date in dates {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            if let weekStart = calendar.date(from: comps) {
                weeks.insert(weekStart)
            }
        }

        var streak = 0
        var cursor = calendar.date(from: calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: Date()))
        // A workout earlier this week already counts the current week.
        while let week = cursor, weeks.contains(week) {
            streak += 1
            cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: week)
        }
        return streak
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
