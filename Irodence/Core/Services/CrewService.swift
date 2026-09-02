import Foundation
import Supabase

/// Service for Crews (熔炉), Crew Heat (炉温), Strikes (锤击), Rust (生锈) & Nudges (催一下).
@MainActor
public final class CrewService: ObservableObject {
    @Published public var currentCrew: Crew?
    @Published public var members: [CrewMember] = []
    @Published public var currentHeat: CrewHeat?
    @Published public var availableCrews: [Crew] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    private let client = SupabaseService.client

    public init() {
        let crewID = UUID()
        self.currentCrew = Crew(
            id: crewID,
            name: "玄铁重工",
            description: "同炉淬火，生锈必催",
            avatarURL: nil,
            createdBy: UUID(),
            weeklyHeatTarget: 1000,
            memberCount: 8,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        self.currentHeat = CrewHeat(
            id: UUID(),
            crewID: crewID,
            weekStart: "2026-08-24",
            totalHeat: 840,
            targetHeat: 1000,
            isQuenched: false,
            quenchedAt: nil
        )
        self.members = [
            CrewMember(
                id: UUID(), crewID: crewID, userID: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
                role: "captain", strikesCount: 18,
                lastActiveAt: Date(), joinedAt: Date(),
                displayName: "铁友 (你)", avatarURL: nil
            ),
            CrewMember(
                id: UUID(), crewID: crewID,
                userID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                role: "member", strikesCount: 14,
                lastActiveAt: Date().addingTimeInterval(-3600 * 24),
                joinedAt: Date(), displayName: "大力水手", avatarURL: nil
            ),
            CrewMember(
                id: UUID(), crewID: crewID,
                userID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                role: "member", strikesCount: 3,
                lastActiveAt: Date().addingTimeInterval(-3600 * 24 * 6), // >5 days -> rusted
                joinedAt: Date(), displayName: "闪电麦昆", avatarURL: nil
            )
        ]
    }

    /// Loads the active crew for the given user, or lists available crews if not joined.
    public func loadUserCrew(userID: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Find membership
            let memberships: [CrewMember] = try await client
                .from("crew_members")
                .select("""
                    *,
                    profiles(display_name, avatar_url)
                """)
                .eq("user_id", value: userID)
                .limit(1)
                .execute()
                .value

            if let membership = memberships.first {
                // Concurrently fetch crew details, all crew members, and current week heat
                async let crewQuery: Crew = client
                    .from("crews")
                    .select("*")
                    .eq("id", value: membership.crewID)
                    .single()
                    .execute()
                    .value

                async let membersQuery: [CrewMember] = client
                    .from("crew_members")
                    .select("""
                        *,
                        profiles(display_name, avatar_url)
                    """)
                    .eq("crew_id", value: membership.crewID)
                    .order("strikes_count", ascending: false)
                    .execute()
                    .value

                async let heatQuery: [CrewHeat] = client
                    .from("crew_heat")
                    .select("*")
                    .eq("crew_id", value: membership.crewID)
                    .order("week_start", ascending: false)
                    .limit(1)
                    .execute()
                    .value

                let (crew, allMembers, heatRows) = try await (crewQuery, membersQuery, heatQuery)

                self.currentCrew = crew
                self.members = allMembers
                self.currentHeat = heatRows.first
                self.availableCrews = []
            } else {
                let crews: [Crew] = try await client
                    .from("crews")
                    .select("*")
                    .order("member_count", ascending: false)
                    .limit(20)
                    .execute()
                    .value
                self.currentCrew = nil
                self.members = []
                self.currentHeat = nil
                self.availableCrews = crews
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    public func fetchAvailableCrews() async {
        do {
            let crews: [Crew] = try await client
                .from("crews")
                .select("*")
                .order("member_count", ascending: false)
                .limit(20)
                .execute()
                .value
            self.availableCrews = crews
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    public func createCrew(name: String, description: String?, weeklyHeatTarget: Int = 100, userID: UUID) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        struct CrewInsert: Encodable {
            let name: String
            let description: String?
            let created_by: UUID
            let weekly_heat_target: Int
            let member_count: Int
            let is_active: Bool
        }

        let newCrew: Crew = try await client
            .from("crews")
            .insert(CrewInsert(
                name: trimmedName,
                description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
                created_by: userID,
                weekly_heat_target: max(weeklyHeatTarget, 100),
                member_count: 1,
                is_active: false
            ))
            .select()
            .single()
            .execute()
            .value

        struct MemberInsert: Encodable {
            let crew_id: UUID
            let user_id: UUID
            let role: String
        }

        try await client
            .from("crew_members")
            .insert(MemberInsert(crew_id: newCrew.id, user_id: userID, role: "leader"))
            .execute()

        await loadUserCrew(userID: userID)
    }

    public func leaveCrew(crewID: UUID, userID: UUID) async throws {
        try await client
            .from("crew_members")
            .delete()
            .eq("crew_id", value: crewID)
            .eq("user_id", value: userID)
            .execute()

        self.currentCrew = nil
        self.members = []
        self.currentHeat = nil
        await loadUserCrew(userID: userID)
    }

    public func joinCrew(crewID: UUID, userID: UUID) async throws {
        struct JoinPayload: Encodable {
            let crew_id: UUID
            let user_id: UUID
            let role: String
        }
        let payload = JoinPayload(crew_id: crewID, user_id: userID, role: "member")
        try await client.from("crew_members").insert(payload).execute()
        await loadUserCrew(userID: userID)
    }

    public func sendNudge(crewID: UUID, senderID: UUID, targetID: UUID) async throws {
        struct NudgePayload: Encodable {
            let crew_id: UUID
            let sender_id: UUID
            let target_id: UUID
        }
        let payload = NudgePayload(crew_id: crewID, sender_id: senderID, target_id: targetID)
        try await client.from("crew_nudges").insert(payload).execute()
    }
}
