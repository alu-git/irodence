import Foundation
import Supabase

/// Follows + leaderboard data access.
@MainActor
final class SocialService: ObservableObject {
    @Published private(set) var followingIDs: Set<UUID> = []
    @Published private(set) var entries: [LeaderboardEntry] = []
    @Published private(set) var weeklyVolume: [WeeklyVolumeEntry] = []
    @Published private(set) var searchResults: [Profile] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseService.client
    let userID: UUID

    init(userID: UUID) {
        self.userID = userID
    }

    // MARK: - Follows

    func loadFollowing() async {
        struct Row: Decodable { let followee_id: UUID }
        do {
            let rows: [Row] = try await client
                .from("follows")
                .select("followee_id")
                .eq("follower_id", value: userID)
                .execute()
                .value
            followingIDs = Set(rows.map(\.followee_id))
        } catch {
            errorMessage = "加载关注列表失败"
        }
    }

    struct FollowInsert: Encodable {
        let follower_id: UUID
        let followee_id: UUID
    }

    func follow(_ followeeID: UUID) async {
        do {
            try await client
                .from("follows")
                .insert(FollowInsert(follower_id: userID, followee_id: followeeID))
                .execute()
            followingIDs.insert(followeeID)
        } catch {
            errorMessage = "关注失败"
        }
    }

    func unfollow(_ followeeID: UUID) async {
        do {
            try await client
                .from("follows")
                .delete()
                .eq("follower_id", value: userID)
                .eq("followee_id", value: followeeID)
                .execute()
            followingIDs.remove(followeeID)
        } catch {
            errorMessage = "取消关注失败"
        }
    }

    // MARK: - User search

    func searchUsers(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        do {
            searchResults = try await client
                .from("profiles")
                .select()
                .ilike("display_name", pattern: "%\(query)%")
                .limit(20)
                .execute()
                .value
        } catch {
            errorMessage = "搜索失败"
        }
    }

    // MARK: - Leaderboards

    /// All best-lift entries for one exercise. Friend filtering and sorting
    /// happen client-side (the view returns at most one row per user).
    func loadLeaderboard(exerciseID: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            entries = try await client
                .from("leaderboard_entries")
                .select()
                .eq("exercise_id", value: exerciseID)
                .execute()
                .value
        } catch {
            errorMessage = "排行榜加载失败"
        }
    }

    func loadWeeklyVolume() async {
        isLoading = true
        defer { isLoading = false }
        do {
            weeklyVolume = try await client
                .from("weekly_volume")
                .select()
                .order("total_volume_kg", ascending: false)
                .execute()
                .value
        } catch {
            errorMessage = "容量榜加载失败"
        }
    }
}
