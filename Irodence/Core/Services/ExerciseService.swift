import Foundation
import Supabase

/// Loads the exercise library from Supabase. The library is global and
/// read-only (RLS), so it is fetched once per launch and cached ON DISK —
/// cached rows render instantly on cold start while a background refresh
/// swaps in fresh data.
@MainActor
final class ExerciseService: ObservableObject {
    @Published private(set) var exercises: [Exercise] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseService.client
    private var hasRefreshedThisLaunch = false

    init() {
        if let cached = Self.loadCache() {
            exercises = cached
            for exercise in cached {
                ExerciseIDCache.shared.register(exerciseID: exercise.id, nameEn: exercise.nameEn)
            }
        }
    }

    func loadIfNeeded() async {
        guard !hasRefreshedThisLaunch, !isLoading else { return }
        hasRefreshedThisLaunch = true
        await reload()
    }

    func reload() async {
        isLoading = exercises.isEmpty
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fetched: [Exercise] = try await withThrowingTaskGroup(of: [Exercise].self) { group in
                group.addTask {
                    try await self.client
                        .from("exercises")
                        .select()
                        .order("name_zh")
                        .execute()
                        .value
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
                self.exercises = fetched
                for exercise in fetched {
                    ExerciseIDCache.shared.register(exerciseID: exercise.id, nameEn: exercise.nameEn)
                }
                Self.saveCache(fetched)
            }
        } catch {
            if exercises.isEmpty {
                exercises = Self.defaultExercises
                for exercise in exercises {
                    ExerciseIDCache.shared.register(exerciseID: exercise.id, nameEn: exercise.nameEn)
                }
            }
        }
    }

    static var defaultExercises: [Exercise] {
        [
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111101")!, nameEn: "Barbell Back Squat", nameZh: "杠铃后深蹲", primaryMuscle: .quads, equipment: .barbell, isCompound: true),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111102")!, nameEn: "Bench Press", nameZh: "杠铃卧推", primaryMuscle: .chest, equipment: .barbell, isCompound: true),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111103")!, nameEn: "Deadlift", nameZh: "传统硬拉", primaryMuscle: .back, equipment: .barbell, isCompound: true),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111104")!, nameEn: "Overhead Press", nameZh: "杠铃过顶推举", primaryMuscle: .shoulders, equipment: .barbell, isCompound: true),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111105")!, nameEn: "Barbell Row", nameZh: "杠铃划船", primaryMuscle: .back, equipment: .barbell, isCompound: true),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111106")!, nameEn: "Lat Pulldown", nameZh: "高位下拉", primaryMuscle: .back, equipment: .cable, isCompound: true),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111107")!, nameEn: "Incline Dumbbell Press", nameZh: "上斜哑铃卧推", primaryMuscle: .chest, equipment: .dumbbell, isCompound: true),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111108")!, nameEn: "Romanian Deadlift", nameZh: "罗马尼亚硬拉", primaryMuscle: .hamstrings, equipment: .barbell, isCompound: true),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111109")!, nameEn: "Leg Press", nameZh: "倒蹬机压腿", primaryMuscle: .quads, equipment: .machine, isCompound: true),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111110")!, nameEn: "Dumbbell Lateral Raise", nameZh: "哑铃侧平举", primaryMuscle: .shoulders, equipment: .dumbbell, isCompound: false),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, nameEn: "Triceps Pushdown", nameZh: "绳索三头下压", primaryMuscle: .triceps, equipment: .cable, isCompound: false),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111112")!, nameEn: "Barbell Biceps Curl", nameZh: "杠铃二头弯举", primaryMuscle: .biceps, equipment: .barbell, isCompound: false),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111113")!, nameEn: "Leg Curl", nameZh: "俯卧腿弯举", primaryMuscle: .hamstrings, equipment: .machine, isCompound: false),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111114")!, nameEn: "Leg Extension", nameZh: "坐姿腿屈伸", primaryMuscle: .quads, equipment: .machine, isCompound: false),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111115")!, nameEn: "Standing Calf Raise", nameZh: "站姿提踵", primaryMuscle: .calves, equipment: .machine, isCompound: false),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111116")!, nameEn: "Cable Woodchopper", nameZh: "绳索伐木砍", primaryMuscle: .core, equipment: .cable, isCompound: false),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111117")!, nameEn: "Pull-up", nameZh: "引体向上", primaryMuscle: .back, equipment: .bodyweight, isCompound: true),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111118")!, nameEn: "Dips", nameZh: "双杠臂屈伸", primaryMuscle: .triceps, equipment: .bodyweight, isCompound: true),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111119")!, nameEn: "Hip Thrust", nameZh: "杠铃臀推", primaryMuscle: .glutes, equipment: .barbell, isCompound: true),
            Exercise(id: UUID(uuidString: "11111111-1111-1111-1111-111111111120")!, nameEn: "Face Pull", nameZh: "绳索面拉", primaryMuscle: .shoulders, equipment: .cable, isCompound: false)
        ]
    }

    // MARK: - Disk cache

    private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("exercise_library.json")
    }

    private static func loadCache() -> [Exercise]? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode([Exercise].self, from: data)
    }

    private static func saveCache(_ exercises: [Exercise]) {
        guard let data = try? JSONEncoder().encode(exercises) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    /// Exercises grouped by muscle group for the library list. Sorted by
    /// the active-language name so ordering follows the language setting.
    var grouped: [(muscle: MuscleGroup, exercises: [Exercise])] {
        Dictionary(grouping: exercises, by: \.primaryMuscle)
            .map { ($0.key, $0.value.sorted { $0.primaryName < $1.primaryName }) }
            .sorted { $0.0.displayName < $1.0.displayName }
    }

    func search(_ query: String) -> [Exercise] {
        guard !query.isEmpty else { return exercises }
        let q = query.lowercased()
        return exercises.filter {
            $0.nameZh.contains(query) || $0.nameEn.lowercased().contains(q)
        }
    }
}
