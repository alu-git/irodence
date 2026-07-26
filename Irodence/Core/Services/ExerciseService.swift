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
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            exercises = try await client
                .from("exercises")
                .select()
                .order("name_zh")
                .execute()
                .value
            // Register core-lift IDs for tier/DOTS lookups elsewhere
            for exercise in exercises {
                ExerciseIDCache.shared.register(exerciseID: exercise.id, nameEn: exercise.nameEn)
            }
            Self.saveCache(exercises)
        } catch {
            // Keep showing cached data; only surface an error if we have nothing
            if exercises.isEmpty {
                errorMessage = L10n.t("动作库加载失败，请检查网络", "Couldn't load the exercise library — check your connection")
            }
        }
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
