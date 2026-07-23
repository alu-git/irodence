import Foundation
import Supabase

/// Loads the exercise library from Supabase. The library is global and
/// read-only (RLS), so it is fetched once and cached in memory.
@MainActor
final class ExerciseService: ObservableObject {
    @Published private(set) var exercises: [Exercise] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseService.client

    func loadIfNeeded() async {
        guard exercises.isEmpty, !isLoading else { return }
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
        } catch {
            errorMessage = "动作库加载失败，请检查网络"
        }
    }

    /// Exercises grouped by muscle group for the library list.
    var grouped: [(muscle: MuscleGroup, exercises: [Exercise])] {
        Dictionary(grouping: exercises, by: \.primaryMuscle)
            .map { ($0.key, $0.value.sorted { $0.nameZh < $1.nameZh }) }
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
