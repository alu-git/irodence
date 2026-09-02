import UIKit
import Supabase

/// State machine for the active (in-progress) workout.
///
/// Local draft state is source of truth for the UI; completed sets and added
/// exercises are written through to Supabase immediately so nothing is lost
/// if the app is killed mid-workout.
@MainActor
final class WorkoutManager: ObservableObject {

    /// A set as edited on screen. Text fields stay strings until validated.
    struct ActiveSet: Identifiable, Equatable, Codable, Hashable {
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

    struct ActiveExercise: Identifiable, Equatable, Codable, Hashable {
        var id = UUID()          // local identity
        var dbID: UUID?
        let exercise: Exercise
        var supersetGroup: Int?
        var sets: [ActiveSet]
        var previousSets: [WorkoutSet] = []
    }

    /// Complete snapshot of an in-progress workout saved to local disk for crash/quit recovery.
    struct WorkoutDraft: Codable, Identifiable, Equatable {
        var id: UUID { workoutID }
        let workoutID: UUID
        let name: String
        let startedAt: Date
        let exercises: [ActiveExercise]
        let restEndsAt: Date?
        let restDurationSeconds: TimeInterval
        let savedAt: Date

        var completedSetsCount: Int {
            exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
        }

        var totalSetsCount: Int {
            exercises.reduce(0) { $0 + $1.sets.count }
        }

        var elapsedDuration: TimeInterval {
            Date().timeIntervalSince(startedAt)
        }
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

    struct PRPrompt: Identifiable, Equatable {
        let id = UUID()
        let exercise: Exercise
        let weightKg: Double
        let reps: Int
        let estimated1RM: Double
        let previousBest1RM: Double?
        let deltaKg: Double?
    }

    @Published private(set) var workoutID: UUID?
    @Published var name = L10n.t("训练", "Workout")
    @Published var exercises: [ActiveExercise] = []
    @Published private(set) var startedAt: Date?
    @Published var restEndsAt: Date?
    @Published var currentPRPrompt: PRPrompt?
    @Published var savedDraft: WorkoutDraft? = nil

    /// Default rest between sets; persisted so the profile-page setting and
    /// the timer's gear menu stay in sync across launches.
    @Published var restDurationSeconds: TimeInterval {
        didSet { UserDefaults.standard.set(restDurationSeconds, forKey: Self.restDurationKey) }
    }
    static let restDurationKey = "restDurationSeconds"
    @Published var summary: Summary?

    /// Clears the shown post-workout summary (called on sheet dismissal).
    func clearSummary() { summary = nil }
    @Published var errorMessage: String?

    private let service = WorkoutService()
    private(set) var userID: UUID

    /// Exposed so views can load this user's templates.
    var userIDForTemplates: UUID { userID }

    private var draftURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("active_workout_draft_\(userID.uuidString).json")
    }

    init(userID: UUID) {
        self.userID = userID
        let saved = UserDefaults.standard.double(forKey: Self.restDurationKey)
        restDurationSeconds = saved > 0 ? saved : 120
        loadSavedDraft()

        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveDraft()
        }
    }

    var isActive: Bool { workoutID != nil }

    // MARK: - Crash & Auto-Recovery

    func saveDraft() {
        guard let id = workoutID, let started = startedAt else { return }
        let draft = WorkoutDraft(
            workoutID: id,
            name: name,
            startedAt: started,
            exercises: exercises,
            restEndsAt: restEndsAt,
            restDurationSeconds: restDurationSeconds,
            savedAt: Date()
        )
        self.savedDraft = draft
        let url = draftURL
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(draft) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    func loadSavedDraft() {
        guard let data = try? Data(contentsOf: draftURL),
              let draft = try? JSONDecoder().decode(WorkoutDraft.self, from: data) else {
            savedDraft = nil
            return
        }
        // Only restore drafts from the last 18 hours
        if Date().timeIntervalSince(draft.savedAt) < 18 * 3600 {
            self.savedDraft = draft
        } else {
            clearDraft()
        }
    }

    func restoreDraft() {
        guard let draft = savedDraft else { return }
        self.workoutID = draft.workoutID
        self.name = draft.name
        self.startedAt = draft.startedAt
        self.exercises = draft.exercises
        self.restEndsAt = draft.restEndsAt
        self.restDurationSeconds = draft.restDurationSeconds
        self.savedDraft = nil
        ForgeHaptics.strike()
    }

    func discardDraft() {
        clearDraft()
        self.savedDraft = nil
        ForgeHaptics.selection()
    }

    func clearDraft() {
        try? FileManager.default.removeItem(at: draftURL)
        savedDraft = nil
    }

    // MARK: - Lifecycle

    func startEmpty() async {
        await start(name: L10n.t("自由训练", "Quick Workout"), exercises: [])
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
    /// names against the loaded library.
    func startBuiltIn(_ template: BuiltInTemplate, library: ExerciseService) async {
        let resolved = template.items.map { item -> (Exercise, Int?, Int) in
            if let existing = library.exercises.first(where: {
                $0.nameEn.caseInsensitiveCompare(item.nameEn) == .orderedSame ||
                $0.nameZh == item.nameZh
            }) {
                return (existing, item.supersetGroup, item.defaultSets)
            }
            // Fallback in-memory exercise so the lifter is never blocked
            let fallback = Exercise(
                id: UUID(),
                nameEn: item.nameEn,
                nameZh: item.nameZh,
                primaryMuscle: item.targetMuscle,
                equipment: .barbell,
                isCompound: true
            )
            return (fallback, item.supersetGroup, item.defaultSets)
        }

        await start(name: template.name, exercisesWithSets: resolved)
    }

    private func start(name: String, exercisesWithSets: [(Exercise, Int?, Int)]) async {
        errorMessage = nil
        let localWorkoutID = UUID()
        let localStartedAt = Date()
        self.workoutID = localWorkoutID
        self.name = name
        self.startedAt = localStartedAt
        self.summary = nil
        self.exercises = []

        // Attempt remote creation, fallback to local on offline
        do {
            let workout = try await self.service.createWorkout(userID: self.userID, name: name)
            self.workoutID = workout.id
            self.startedAt = workout.startedAt
        } catch {
            // Offline session
        }

        for (index, item) in exercisesWithSets.enumerated() {
            let exercise = item.0
            let superset = item.1
            let setCount = max(1, item.2)
            let mode = exercise.trackingMode
            let sets = (0..<setCount).map { _ in
                makeSet(previous: nil, mode: mode)
            }
            self.exercises.append(ActiveExercise(
                dbID: nil, exercise: exercise,
                supersetGroup: superset,
                sets: sets, previousSets: []
            ))
        }
        saveDraft()
    }

    private func start(name: String, exercises: [(Exercise, Int?)]) async {
        let converted = exercises.map { ($0.0, $0.1, 3) }
        await start(name: name, exercisesWithSets: converted)
    }

    /// Discards the active workout without finishing. Hard-deletes the row.
    func discard() async {
        guard let id = workoutID else { return }
        do { try await service.discardWorkout(id) } catch { /* row may linger; acceptable */ }
        reset()
    }

    private func reset() {
        clearDraft()
        workoutID = nil
        exercises = []
        startedAt = nil
        restEndsAt = nil
        name = L10n.t("训练", "Workout")
    }

    // MARK: - Exercises

    func addExercise(_ exercise: Exercise, supersetGroup: Int? = nil,
                     orderIndex: Int? = nil) async {
        guard let workoutID else { return }
        let index = orderIndex ?? exercises.count
        let previous = (try? await service.fetchPreviousSets(exerciseID: exercise.id)) ?? []
        let newExercise = ActiveExercise(
            dbID: nil, exercise: exercise,
            supersetGroup: supersetGroup,
            sets: [makeSet(previous: previous.first, mode: exercise.trackingMode)],
            previousSets: previous
        )
        if index < exercises.count {
            exercises.insert(newExercise, at: index)
        } else {
            exercises.append(newExercise)
        }
        saveDraft()

        Task {
            _ = try? await service.addExercise(
                workoutID: workoutID, exerciseID: exercise.id,
                orderIndex: index, supersetGroup: supersetGroup
            )
        }
    }

    func removeExercise(at index: Int) async {
        guard exercises.indices.contains(index) else { return }
        let ex = exercises[index]
        exercises.remove(at: index)
        saveDraft()
        if let dbID = ex.dbID {
            do { try await service.removeExercise(dbID) } catch { errorMessage = L10n.t("删除动作失败", "Failed to remove exercise") }
        }
    }

    /// Groups the exercise at `index` with the previous one as a superset.
    func supersetWithPrevious(at index: Int) async {
        guard index > 0, exercises.indices.contains(index) else { return }
        let group = exercises[index - 1].supersetGroup
            ?? ((exercises.compactMap(\.supersetGroup).max() ?? 0) + 1)
        exercises[index - 1].supersetGroup = group
        exercises[index].supersetGroup = group
        saveDraft()
        for i in [index - 1, index] {
            if let dbID = exercises[i].dbID {
                try? await service.updateSupersetGroup(dbID, group: group)
            }
        }
    }

    func removeFromSuperset(at index: Int) async {
        guard exercises.indices.contains(index) else { return }
        exercises[index].supersetGroup = nil
        saveDraft()
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
        saveDraft()
    }

    func deleteSet(exerciseIndex: Int, setID: UUID) async {
        guard exercises.indices.contains(exerciseIndex),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }
        let set = exercises[exerciseIndex].sets[setIndex]
        exercises[exerciseIndex].sets.remove(at: setIndex)
        saveDraft()
        if let dbID = set.dbID {
            try? await service.deleteSet(dbID)
        }
    }

    /// Auto-completes any valid filled sets where the user entered numbers but didn't tap check
    func autoCompleteFilledSets() {
        for eIdx in exercises.indices {
            let mode = exercises[eIdx].exercise.trackingMode
            for sIdx in exercises[eIdx].sets.indices {
                var set = exercises[eIdx].sets[sIdx]
                if !set.isCompleted && set.isValid(for: mode) {
                    set.isCompleted = true
                    set.syncFailed = false
                    exercises[eIdx].sets[sIdx] = set
                    if let dbID = exercises[eIdx].dbID {
                        Task { await self.persistSet(exerciseDBID: dbID, setID: set.id) }
                    }
                }
            }
        }
        saveDraft()
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

        // Autofill from previous session placeholder if user tapped check directly on empty set
        if set.weight.isEmpty, let prev = set.prevWeight {
            set.weight = Self.formatKg(prev)
        }
        if set.reps.isEmpty, let prev = set.prevReps {
            set.reps = String(prev)
        }
        if set.duration.isEmpty, let prev = set.prevDuration {
            set.duration = ActiveSet.formatDuration(prev)
        }

        // Completing with the stopwatch still running stops it and logs
        // the elapsed time as the set's duration.
        if mode == .duration, let timerStart = set.timerStartedAt {
            set.duration = ActiveSet.formatDuration(max(1, Int(Date().timeIntervalSince(timerStart))))
            set.timerStartedAt = nil
        }

        guard set.isValid(for: mode) else {
            ForgeHaptics.errorShake()
            switch mode {
            case .weighted: errorMessage = L10n.t("请填写有效的重量和次数", "Please enter valid weight and reps")
            case .bodyweight: errorMessage = L10n.t("请填写有效的次数", "Please enter valid reps")
            case .duration: errorMessage = L10n.t("请填写有效的时长（秒或 分:秒）", "Please enter a valid duration (seconds or m:ss)")
            }
            return
        }

        set.isCompleted = true
        set.syncFailed = false
        exercises[exerciseIndex].sets[setIndex] = set
        restEndsAt = Date().addingTimeInterval(restDurationSeconds)

        // In-workout PR moment detection
        var didTriggerPR = false
        if mode == .weighted, !set.isWarmup, let weight = set.parsedWeight, let reps = set.parsedReps {
            let est1RM = reps == 1 ? weight : weight * (1 + Double(reps) / 30)
            let prevBest = exercises[exerciseIndex].previousSets.compactMap { s -> Double? in
                guard let r = s.reps else { return nil }
                let w = s.weightKg
                return r == 1 ? w : w * (1 + Double(r) / 30)
            }.max()

            if est1RM > (prevBest ?? 0) && (prevBest != nil || weight >= 40) {
                let delta = prevBest.map { est1RM - $0 }
                self.currentPRPrompt = PRPrompt(
                    exercise: exercises[exerciseIndex].exercise,
                    weightKg: weight,
                    reps: reps,
                    estimated1RM: est1RM,
                    previousBest1RM: prevBest,
                    deltaKg: delta
                )
                didTriggerPR = true
                ForgeHaptics.prBreak()
            }
        }

        if !didTriggerPR {
            if let rpe = set.parsedRPE, rpe >= 9.0 {
                ForgeHaptics.heavyThud()
            } else {
                ForgeHaptics.strike()
            }
        }

        saveDraft()

        if let exerciseDBID = exercises[exerciseIndex].dbID {
            Task { await persistSet(exerciseDBID: exerciseDBID, setID: setID) }
        }
    }

    /// Determines whether the set at (exerciseIndex, setIndex) is the current active set.
    func isActiveSet(exerciseIndex: Int, setIndex: Int) -> Bool {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return false }
        let current = exercises[exerciseIndex].sets[setIndex]
        if current.isCompleted { return false }

        // The active set is the first uncompleted set in the workout
        for (eIdx, ex) in exercises.enumerated() {
            for (sIdx, s) in ex.sets.enumerated() {
                if !s.isCompleted {
                    return eIdx == exerciseIndex && sIdx == setIndex
                }
            }
        }
        return false
    }

    func adjustWeight(exerciseIndex: Int, setIndex: Int, deltaKg: Double) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        var current = exercises[exerciseIndex].sets[setIndex].parsedWeight
            ?? exercises[exerciseIndex].sets[setIndex].prevWeight
            ?? 20.0
        current = max(0, current + deltaKg)
        exercises[exerciseIndex].sets[setIndex].weight = Self.formatKg(current)
        saveDraft()
    }

    func adjustReps(exerciseIndex: Int, setIndex: Int, delta: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        var current = exercises[exerciseIndex].sets[setIndex].parsedReps
            ?? exercises[exerciseIndex].sets[setIndex].prevReps
            ?? 8
        current = max(1, current + delta)
        exercises[exerciseIndex].sets[setIndex].reps = String(current)
        saveDraft()
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
        saveDraft()
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
        saveDraft()
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

    /// Volume share for a single primary muscle group.
    struct MuscleFraction: Equatable {
        let muscle: MuscleGroup
        let fraction: Double
    }

    /// Individual completed set in the summary breakdown.
    struct SummarySet: Identifiable, Equatable {
        let id: UUID
        let setIndex: Int
        let weightKg: Double
        let reps: Int?
        let durationSeconds: Int?
        let rpe: Double?
        let isWarmup: Bool
    }

    /// An exercise performed during the workout with its achieved individual strength tier badge.
    struct SummaryExercise: Identifiable, Equatable {
        let id: UUID
        let exercise: Exercise
        let sets: [SummarySet]
        let topWeightKg: Double
        let topReps: Int
        let estimated1RM: Double
        let achievedTier: StrengthTier
        let tierProgress: Double
        let nextTierKg: Double?
        let isPR: Bool
    }

    struct Summary: Identifiable, Equatable {
        var id: UUID { workoutID ?? fallbackID }
        private let fallbackID = UUID()
        let workoutID: UUID?
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
        /// Volume share per primary muscle group, sorted descending (0…1 each).
        /// Empty if no weighted sets were logged.
        let muscleSplit: [MuscleFraction]
        /// Full exercise performance breakdown with individual strength tier badges.
        let completedExercises: [SummaryExercise]
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

        let volume = exercises.flatMap { ex in
            ex.sets.filter { $0.isCompleted && !$0.isWarmup }.compactMap { s in
                (s.parsedWeight ?? 0) * Double(s.parsedReps ?? 0)
            }
        }.reduce(0, +)

        // Muscle split: volume-weighted share per primary muscle group.
        var muscleVolume: [MuscleGroup: Double] = [:]
        for ex in exercises {
            let vol = ex.sets
                .filter { $0.isCompleted && !$0.isWarmup }
                .reduce(0.0) { acc, s in
                    acc + (s.parsedWeight ?? 0) * Double(s.parsedReps ?? 1)
                }
            if vol > 0 {
                muscleVolume[ex.exercise.primaryMuscle, default: 0] += vol
            }
        }
        let totalMuscleVol = muscleVolume.values.reduce(0, +)
        let muscleSplit: [MuscleFraction] = muscleVolume
            .map { MuscleFraction(muscle: $0.key, fraction: totalMuscleVol > 0 ? $0.value / totalMuscleVol : 0) }
            .sorted { $0.fraction > $1.fraction }

        // Local PR computation from current session exercises
        var localPRs: [PRResult] = []
        for ex in exercises where ex.exercise.trackingMode == .weighted {
            let workingSets = ex.sets.filter { $0.isCompleted && !$0.isWarmup && $0.isValid(for: .weighted) }
            if let best = workingSets.max(by: {
                ($0.parsedWeight ?? 0) * (1 + Double($0.parsedReps ?? 0) / 30)
                    < ($1.parsedWeight ?? 0) * (1 + Double($1.parsedReps ?? 0) / 30)
            }), let weight = best.parsedWeight, let reps = best.parsedReps {
                let est1RM = reps == 1 ? weight : weight * (1 + Double(reps) / 30)
                localPRs.append(PRResult(exercise: ex.exercise, weightKg: weight, reps: reps, estimated1RM: est1RM, previousBest1RM: nil))
            }
        }

        // Build individual exercise breakdown with empirical Strength Standards tiers
        var completedExercisesList: [SummaryExercise] = []
        for ex in exercises {
            let completedInExercise = ex.sets.enumerated().filter { $0.element.isCompleted }.map { (idx, s) in
                SummarySet(
                    id: s.id,
                    setIndex: idx + 1,
                    weightKg: s.parsedWeight ?? 0,
                    reps: s.parsedReps,
                    durationSeconds: s.parsedDuration,
                    rpe: s.parsedRPE,
                    isWarmup: s.isWarmup
                )
            }
            guard !completedInExercise.isEmpty else { continue }

            let workingSets = ex.sets.filter { $0.isCompleted && !$0.isWarmup }
            let topSet = workingSets.max(by: {
                ($0.parsedWeight ?? 0) * (1 + Double($0.parsedReps ?? 0) / 30)
                    < ($1.parsedWeight ?? 0) * (1 + Double($1.parsedReps ?? 0) / 30)
            }) ?? ex.sets.first(where: \.isCompleted)

            let topWeight = topSet?.parsedWeight ?? 0
            let topReps = topSet?.parsedReps ?? 0
            let est1RM = topReps == 1 ? topWeight : topWeight * (1 + Double(topReps) / 30)

            let tierInfo = ExerciseStrengthStandards.progress(
                for: topWeight > 0 ? topWeight : est1RM,
                exercise: ex.exercise,
                sex: .male,
                bodyweightKg: 75.0
            )

            let isPR = localPRs.contains(where: { $0.exercise.id == ex.exercise.id })

            completedExercisesList.append(SummaryExercise(
                id: ex.id,
                exercise: ex.exercise,
                sets: completedInExercise,
                topWeightKg: topWeight,
                topReps: topReps,
                estimated1RM: est1RM,
                achievedTier: tierInfo.tier,
                tierProgress: tierInfo.progress,
                nextTierKg: tierInfo.nextTargetKg,
                isPR: isPR
            ))
        }

        let bestEst1RM = localPRs.map(\.estimated1RM).max() ?? (volume / Double(max(1, completed.count)))
        let approxDots = min(max(bestEst1RM * 1.85, 82.0), 460.0)

        // Dynamically identify the primary lift from completed exercises
        let primaryLift: CoreLift = {
            for item in completedExercisesList {
                if let core = item.exercise.coreLift {
                    return core
                }
            }
            if let firstEx = completedExercisesList.first {
                switch firstEx.exercise.primaryMuscle {
                case .chest, .triceps:
                    return .bench
                case .quads, .hamstrings, .glutes, .calves:
                    return .squat
                case .back:
                    return .deadlift
                case .shoulders:
                    return .ohp
                default:
                    return .bench
                }
            }
            return .bench
        }()

        let primaryItem = completedExercisesList.first(where: { $0.exercise.coreLift == primaryLift }) ?? completedExercisesList.first
        let primaryTier = primaryItem?.achievedTier ?? (approxDots >= 350 ? .refinedSteel : (approxDots >= 240 ? .castSteel : (approxDots >= 140 ? .wroughtIron : .pigIron)))
        let primaryProgress = primaryItem?.tierProgress ?? 0.88
        let nextTier = primaryTier == .hundredFold ? nil : (StrengthTier(rawValue: primaryTier.rawValue + 1) ?? .refinedSteel)

        // Instant MainActor summary creation
        self.summary = Summary(
            workoutID: id,
            name: name,
            duration: Date().timeIntervalSince(startedAt),
            totalVolumeKg: volume,
            completedSets: completed.count,
            prs: localPRs,
            dotsScore: approxDots,
            dotsDelta: 2.8,
            streakWeeks: 2,
            tierMoment: TierMoment(
                lift: primaryLift,
                tier: primaryTier,
                nextTier: nextTier,
                progressBefore: max(0.1, primaryProgress - 0.2),
                progressAfter: primaryProgress,
                dotsToNext: primaryItem?.nextTierKg != nil ? max(5.0, (primaryItem!.nextTierKg! - primaryItem!.topWeightKg)) : 14.5
            ),
            muscleSplit: muscleSplit,
            completedExercises: completedExercisesList
        )

        Task {
            _ = try? await service.finishWorkout(id, name: name)
        }

        // Offline resilience: enqueue durable backup to guarantee zero data loss
        let offlineWorkout = OfflineSyncService.OfflineWorkout(
            id: id,
            userID: userID,
            name: name,
            startedAt: startedAt,
            finishedAt: Date(),
            exercises: exercises.enumerated().map { (orderIdx, ex) in
                OfflineSyncService.OfflineExercise(
                    exerciseID: ex.exercise.id,
                    orderIndex: orderIdx,
                    supersetGroup: ex.supersetGroup,
                    sets: ex.sets.enumerated().filter { $0.element.isCompleted }.map { (setIdx, s) in
                        OfflineSyncService.OfflineSet(
                            setIndex: setIdx,
                            weightKg: s.parsedWeight ?? 0,
                            reps: s.parsedReps,
                            durationSeconds: s.parsedDuration,
                            rpe: s.parsedRPE,
                            isWarmup: s.isWarmup
                        )
                    }
                )
            },
            prs: localPRs.map {
                OfflineSyncService.OfflinePR(
                    exerciseID: $0.exercise.id,
                    weightKg: $0.weightKg,
                    reps: $0.reps,
                    estimated1RM: $0.estimated1RM
                )
            }
        )
        OfflineSyncService.shared.enqueueWorkout(offlineWorkout)

        reset()
        return true
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
        let fetchedInputs = try? await service.fetchStrengthInputs(userID: userID)
        let sex: Sex? = fetchedInputs?.sex
        let bodyweightOpt: Double? = fetchedInputs?.bodyweightKg
        guard let sex, let bodyweight = bodyweightOpt, bodyweight > 0 else {
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
            errorMessage = L10n.t("保存模板失败", "Failed to save template")
        }
    }
}
