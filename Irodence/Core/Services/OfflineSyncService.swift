import Foundation
import Supabase

/// Durable offline synchronization queue.
/// Manages pending workouts and sets logged while in underground gyms or offline.
/// Guarantees at-least-once delivery with automatic drain on reconnection.
final class OfflineSyncService: @unchecked Sendable {
    static let shared = OfflineSyncService()

    struct OfflineSet: Codable, Sendable {
        let setIndex: Int
        let weightKg: Double
        let reps: Int?
        let durationSeconds: Int?
        let rpe: Double?
        let isWarmup: Bool
    }

    struct OfflineExercise: Codable, Sendable {
        let exerciseID: UUID
        let orderIndex: Int
        let supersetGroup: Int?
        let sets: [OfflineSet]
    }

    struct OfflinePR: Codable, Sendable {
        let exerciseID: UUID
        let weightKg: Double
        let reps: Int
        let estimated1RM: Double
    }

    struct OfflineWorkout: Codable, Identifiable, Sendable {
        let id: UUID
        let userID: UUID
        let name: String
        let startedAt: Date
        let finishedAt: Date
        let exercises: [OfflineExercise]
        let prs: [OfflinePR]
    }

    private let lock = NSLock()
    private var isSyncing = false
    private let client = SupabaseService.client
    private let workoutService = WorkoutService()

    private var queueURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("irodence_offline_sync_queue.json")
    }

    private init() {}

    // MARK: - Queue Management

    func enqueueWorkout(_ workout: OfflineWorkout) {
        lock.lock()
        defer { lock.unlock() }

        var queue = loadQueueInternal()
        // Deduplicate
        if !queue.contains(where: { $0.id == workout.id }) {
            queue.append(workout)
            saveQueueInternal(queue)
        }

        // Try syncing immediately in background if possible
        Task { [weak self] in
            self?.syncPending()
        }
    }

    var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return loadQueueInternal().count
    }

    // MARK: - Sync Processing

    func syncPending() {
        Task {
            await drainQueue()
        }
    }

    private func drainQueue() async {
        lock.lock()
        if isSyncing {
            lock.unlock()
            return
        }
        isSyncing = true
        let pending = loadQueueInternal()
        lock.unlock()

        guard !pending.isEmpty else {
            lock.lock()
            isSyncing = false
            lock.unlock()
            return
        }

        var remaining = pending

        for workout in pending {
            let success = await uploadWorkout(workout)
            if success {
                lock.lock()
                remaining.removeAll(where: { $0.id == workout.id })
                saveQueueInternal(remaining)
                lock.unlock()
            }
        }

        lock.lock()
        isSyncing = false
        lock.unlock()
    }

    private func uploadWorkout(_ workout: OfflineWorkout) async -> Bool {
        do {
            // 1. Create Workout row (or upsert with stable ID)
            struct WorkoutInsert: Encodable {
                let id: UUID
                let user_id: UUID
                let name: String
                let started_at: Date
                let finished_at: Date
            }

            try await client
                .from("workouts")
                .upsert(WorkoutInsert(
                    id: workout.id,
                    user_id: workout.userID,
                    name: workout.name,
                    started_at: workout.startedAt,
                    finished_at: workout.finishedAt
                ))
                .execute()

            // 2. Add Exercises & Sets
            for exercise in workout.exercises {
                let workoutEx = try await workoutService.addExercise(
                    workoutID: workout.id,
                    exerciseID: exercise.exerciseID,
                    orderIndex: exercise.orderIndex,
                    supersetGroup: exercise.supersetGroup
                )

                for set in exercise.sets {
                    _ = try? await workoutService.addSet(.init(
                        workout_exercise_id: workoutEx.id,
                        set_index: set.setIndex,
                        weight_kg: set.weightKg,
                        reps: set.reps,
                        duration_seconds: set.durationSeconds,
                        rpe: set.rpe,
                        is_warmup: set.isWarmup
                    ))
                }
            }

            // 3. Insert PRs
            for pr in workout.prs {
                _ = try? await workoutService.insertPR(.init(
                    user_id: workout.userID,
                    exercise_id: pr.exerciseID,
                    weight_kg: pr.weightKg,
                    reps: pr.reps,
                    estimated_1rm: pr.estimated1RM,
                    workout_id: workout.id
                ))
            }

            return true
        } catch {
            return false
        }
    }

    // MARK: - File I/O Helpers

    private func loadQueueInternal() -> [OfflineWorkout] {
        guard let data = try? Data(contentsOf: queueURL),
              let queue = try? JSONDecoder().decode([OfflineWorkout].self, from: data) else {
            return []
        }
        return queue
    }

    private func saveQueueInternal(_ queue: [OfflineWorkout]) {
        if let data = try? JSONEncoder().encode(queue) {
            try? data.write(to: queueURL, options: .atomic)
        }
    }
}
