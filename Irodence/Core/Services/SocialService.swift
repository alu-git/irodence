import Foundation
import Supabase

/// Follows + leaderboard data access.
@MainActor
final class SocialService: ObservableObject {
    @Published private(set) var followingIDs: Set<UUID> = []
    @Published private(set) var entries: [LeaderboardEntry] = []
    @Published private(set) var weeklyVolume: [WeeklyVolumeEntry] = []
    @Published private(set) var searchResults: [Profile] = []
    @Published private(set) var recommendations: [Profile] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseService.client
    let userID: UUID

    static let defaultFollowedFriendIDs: Set<UUID> = [
        UUID(uuidString: "22222222-2222-2222-2222-222222222202")!, // 麦昆
        UUID(uuidString: "22222222-2222-2222-2222-222222222204")!, // 琳琳
        UUID(uuidString: "22222222-2222-2222-2222-222222222206")!, // 铁馆老王
        UUID(uuidString: "77777777-7777-7777-7777-777777777701")!, // 张铁峰
        UUID(uuidString: "77777777-7777-7777-7777-777777777702")!  // 陈力量
    ]

    init(userID: UUID) {
        self.userID = userID
        self.followingIDs = Self.defaultFollowedFriendIDs
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
            let fetched = Set(rows.map(\.followee_id))
            followingIDs = fetched.isEmpty ? Self.defaultFollowedFriendIDs : fetched
        } catch {
            // Retain default followed friends in offline/mock mode
            if followingIDs.isEmpty {
                followingIDs = Self.defaultFollowedFriendIDs
            }
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
            recommendations.removeAll { $0.id == followeeID }
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

    // MARK: - Default Mock Community Lifters

    static let defaultCommunityLifters: [Profile] = [
        Profile(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777701")!,
            displayName: "张铁峰",
            avatarURL: nil,
            sex: .male,
            bodyweightKg: 82.5,
            bio: "卧推140kg · 专注三大项力量举 · 状态永不熄火",
            heightCm: 178,
            ageYears: 27
        ),
        Profile(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777702")!,
            displayName: "陈力量 (Leo)",
            avatarURL: nil,
            sex: .male,
            bodyweightKg: 88.0,
            bio: "深蹲200kg · 每日清晨6点开炉打卡",
            heightCm: 182,
            ageYears: 29
        ),
        Profile(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777703")!,
            displayName: "林晨曦",
            avatarURL: nil,
            sex: .female,
            bodyweightKg: 56.0,
            bio: "传统硬拉140kg · 严格动作轨迹与形体美学",
            heightCm: 165,
            ageYears: 25
        ),
        Profile(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777704")!,
            displayName: "赵大力",
            avatarURL: nil,
            sex: .male,
            bodyweightKg: 75.0,
            bio: "杠铃过顶推举75kg · 力量耐力双修",
            heightCm: 174,
            ageYears: 26
        ),
        Profile(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777705")!,
            displayName: "王铁心",
            avatarURL: nil,
            sex: .male,
            bodyweightKg: 91.0,
            bio: "三大项总成绩560kg · 铁馆驻场老兵",
            heightCm: 180,
            ageYears: 32
        ),
        Profile(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777706")!,
            displayName: "孙小敏",
            avatarURL: nil,
            sex: .female,
            bodyweightKg: 52.0,
            bio: "引体向上自重+15kg · 专注背部雕刻",
            heightCm: 162,
            ageYears: 24
        )
    ]

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
            if searchResults.isEmpty {
                let q = query.lowercased()
                searchResults = Self.defaultCommunityLifters.filter {
                    $0.displayName.lowercased().contains(q) || ($0.bio?.lowercased().contains(q) ?? false)
                }
            }
        } catch {
            let q = query.lowercased()
            searchResults = Self.defaultCommunityLifters.filter {
                $0.displayName.lowercased().contains(q) || ($0.bio?.lowercased().contains(q) ?? false)
            }
        }
    }

    // MARK: - Friend recommendations

    /// Suggested users for the add-friends sheet: this week's most active
    /// lifters first (ranked via the weekly_volume view), backfilled with the
    /// newest profiles. Excludes yourself and people you already follow.
    func loadRecommendations() async {
        struct VolumeRow: Decodable { let user_id: UUID }
        do {
            async let volumeQuery: [VolumeRow] = client
                .from("weekly_volume")
                .select("user_id")
                .order("total_volume_kg", ascending: false)
                .limit(30)
                .execute()
                .value
            async let profilesQuery: [Profile] = client
                .from("profiles")
                .select()
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            let (volumeRows, profiles) = try await (volumeQuery, profilesQuery)

            let rank = Dictionary(
                uniqueKeysWithValues: volumeRows.map(\.user_id).enumerated().map { ($1, $0) }
            )
            let candidates = profiles
                .filter { $0.id != userID && !followingIDs.contains($0.id) }
                .sorted { (rank[$0.id] ?? .max) < (rank[$1.id] ?? .max) }
            let loaded = Array(candidates.prefix(10))
            if loaded.isEmpty {
                recommendations = Self.defaultCommunityLifters.filter { $0.id != userID && !followingIDs.contains($0.id) }
            } else {
                recommendations = loaded
            }
        } catch {
            recommendations = Self.defaultCommunityLifters.filter { $0.id != userID && !followingIDs.contains($0.id) }
        }
    }

    /// All best-lift entries for one exercise.
    /// Sparse boards with fewer than minThreshold (3) certified entries are suppressed.
    func loadLeaderboard(exerciseID: UUID, minThreshold: Int = 3) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched: [LeaderboardEntry] = try await client
                .from("leaderboard_entries")
                .select()
                .eq("exercise_id", value: exerciseID)
                .execute()
                .value
            if fetched.count < minThreshold {
                entries = []
            } else {
                entries = fetched
            }
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
