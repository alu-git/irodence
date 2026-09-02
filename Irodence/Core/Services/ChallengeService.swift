import Foundation
import Supabase

/// Service for head-to-head Challenges (比武).
@MainActor
public final class ChallengeService: ObservableObject {
    @Published public var incomingChallenges: [Challenge] = []
    @Published public var activeChallenges: [Challenge] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    private let client = SupabaseService.client

    public init() {}

    public func fetchChallenges(userID: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let list: [Challenge] = try await client
                .from("challenges")
                .select("""
                    *,
                    challenger:profiles!challenges_challenger_id_fkey(display_name, avatar_url),
                    challenged:profiles!challenges_challenged_id_fkey(display_name, avatar_url)
                """)
                .or("challenger_id.eq.\(userID.uuidString),challenged_id.eq.\(userID.uuidString)")
                .order("created_at", ascending: false)
                .execute()
                .value

            self.incomingChallenges = list.filter { $0.challengedID == userID && $0.status == .pending }
            self.activeChallenges = list.filter { $0.status == .active }
        } catch {
            self.errorMessage = error.localizedDescription
            self.incomingChallenges = []
            self.activeChallenges = []
        }
    }

    public func respondToChallenge(challengeID: UUID, accept: Bool) async throws {
        let newStatus = accept ? ChallengeStatus.active.rawValue : ChallengeStatus.declined.rawValue
        try await client
            .from("challenges")
            .update(["status": newStatus])
            .eq("id", value: challengeID)
            .execute()
    }
}
