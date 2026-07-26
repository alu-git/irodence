import Foundation
import Supabase

/// Progress data: per-exercise strength history + bodyweight log.
@MainActor
final class ProgressService: ObservableObject {
    @Published private(set) var history: [StrengthHistoryPoint] = []
    @Published private(set) var bodyweightLogs: [BodyweightLog] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseService.client

    private var userID: UUID? {
        client.auth.currentUser?.id
    }

    // MARK: - Est-1RM history for one exercise

    /// Best Epley est-1RM per calendar day, from all logged sets of one
    /// exercise (warmups excluded), oldest first.
    func loadHistory(exerciseID: UUID) async {
        isLoading = true
        defer { isLoading = false }

        struct JoinedRow: Decodable {
            let workouts: WorkoutDate
            let workout_sets: [SetRow]

            struct WorkoutDate: Decodable { let finished_at: Date? }
            struct SetRow: Decodable {
                let weight_kg: Double
                let reps: Int
                let is_warmup: Bool
            }
        }

        do {
            let rows: [JoinedRow] = try await client
                .from("workout_exercises")
                .select("workouts!inner(finished_at), workout_sets(weight_kg, reps, is_warmup)")
                .eq("exercise_id", value: exerciseID)
                .not("workouts.finished_at", operator: .is, value: "null")
                .execute()
                .value

            var bestByDay: [Date: Double] = [:]
            for row in rows {
                guard let day = row.workouts.finished_at else { continue }
                let dayStart = Calendar.current.startOfDay(for: day)
                for set in row.workout_sets where !set.is_warmup && set.weight_kg > 0 && set.reps > 0 {
                    let epley = set.reps == 1
                        ? set.weight_kg
                        : set.weight_kg * (1 + Double(set.reps) / 30)
                    bestByDay[dayStart] = max(bestByDay[dayStart] ?? 0, epley)
                }
            }

            history = bestByDay
                .map { StrengthHistoryPoint(date: $0.key, estimated1RM: $0.value) }
                .sorted { $0.date < $1.date }
        } catch {
            errorMessage = "历史数据加载失败"
        }
    }

    // MARK: - Bodyweight log

    func loadBodyweightLogs() async {
        guard let userID else { return }
        let key = "bodyweight_\(userID.uuidString)"
        // Show the last snapshot instantly, then refresh silently.
        if bodyweightLogs.isEmpty,
           let cached: [BodyweightLog] = DiskCache.load([BodyweightLog].self, key: key) {
            bodyweightLogs = cached
        }
        do {
            bodyweightLogs = try await client
                .from("bodyweight_logs")
                .select()
                .eq("user_id", value: userID)
                .order("logged_at", ascending: true)
                .execute()
                .value
            DiskCache.save(bodyweightLogs, key: key)
        } catch {
            if bodyweightLogs.isEmpty {
                errorMessage = "体重记录加载失败"
            }
        }
    }

    struct BodyweightInsert: Encodable {
        let user_id: UUID
        let weight_kg: Double
    }

    struct ProfileBodyweightUpdate: Encodable {
        let bodyweight_kg: Double
    }

    /// Appends a dated entry and syncs profiles.bodyweight_kg so the DOTS
    /// calc always uses the freshest value.
    func logBodyweight(_ kg: Double) async -> Bool {
        guard let userID, kg > 0, kg < 500 else {
            errorMessage = "请输入有效的体重"
            return false
        }
        do {
            try await client
                .from("bodyweight_logs")
                .insert(BodyweightInsert(user_id: userID, weight_kg: kg))
                .execute()
            try await client
                .from("profiles")
                .update(ProfileBodyweightUpdate(bodyweight_kg: kg))
                .eq("id", value: userID)
                .execute()
            await loadBodyweightLogs()
            return true
        } catch {
            errorMessage = "保存体重失败"
            return false
        }
    }

    func deleteBodyweightLog(_ id: UUID) async {
        do {
            try await client
                .from("bodyweight_logs")
                .delete()
                .eq("id", value: id)
                .execute()
            await loadBodyweightLogs()
        } catch {
            errorMessage = "删除失败"
        }
    }
}
