import Foundation
import Supabase

/// Manages user-level blocking for safety and anti-harassment.
/// Enforces silent one-tap blocking per IRODENCE_SAFETY.md Section 4:
/// "Blocking hides the blocker's proofs from that account entirely, prevents crew invitations,
/// and is silent to the blocked user."
@MainActor
public final class BlockService: ObservableObject {
    public static let shared = BlockService()

    @Published public private(set) var blockedUserIDs: Set<UUID> = []

    private let storageKey = "irodence_blocked_user_ids"
    private let client = SupabaseService.client

    public init() {
        loadLocalBlocks()
    }

    /// Checks if a user is blocked locally
    public func isBlocked(_ userID: UUID) -> Bool {
        blockedUserIDs.contains(userID)
    }

    /// Blocks a target user silently
    public func blockUser(targetID: UUID, blockerID: UUID) async {
        blockedUserIDs.insert(targetID)
        saveLocalBlocks()

        // Sync with Supabase blocked_users table
        struct BlockPayload: Encodable {
            let blocker_id: UUID
            let blocked_id: UUID
        }

        let payload = BlockPayload(blocker_id: blockerID, blocked_id: targetID)
        try? await client
            .from("blocked_users")
            .insert(payload)
            .execute()
    }

    /// Unblocks a target user
    public func unblockUser(targetID: UUID, blockerID: UUID) async {
        blockedUserIDs.remove(targetID)
        saveLocalBlocks()

        try? await client
            .from("blocked_users")
            .delete()
            .eq("blocker_id", value: blockerID)
            .eq("blocked_id", value: targetID)
            .execute()
    }

    /// Loads blocked users from remote Supabase
    public func fetchBlockedUsers(for blockerID: UUID) async {
        struct BlockRow: Decodable {
            let blocked_id: UUID
        }

        do {
            let rows: [BlockRow] = try await client
                .from("blocked_users")
                .select("blocked_id")
                .eq("blocker_id", value: blockerID)
                .execute()
                .value

            let ids = Set(rows.map(\.blocked_id))
            self.blockedUserIDs = ids
            saveLocalBlocks()
        } catch {
            // Retain local blocks if offline
        }
    }

    private func loadLocalBlocks() {
        if let data = UserDefaults.standard.string(forKey: storageKey) {
            let rawList = data.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
            self.blockedUserIDs = Set(rawList)
        }
    }

    private func saveLocalBlocks() {
        let rawList = blockedUserIDs.map(\.uuidString).joined(separator: ",")
        UserDefaults.standard.set(rawList, forKey: storageKey)
    }
}
