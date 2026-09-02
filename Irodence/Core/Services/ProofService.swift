import Foundation
import Supabase

/// Service for Proofs (证词) and Witnessing (见证).
/// Enforces client-side coordination with server-side validation per IRODENCE_SAFETY.md.
@MainActor
public final class ProofService: ObservableObject {
    @Published public var proofs: [Proof] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    private let client = SupabaseService.client
    private let blockService = BlockService.shared

    public init() {
        // Pre-populate with default proofs for instant zero-delay render
        self.proofs = [
            Proof(
                id: UUID(),
                userID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                exerciseID: UUID(),
                weightKg: 140.0,
                reps: 3,
                estimated1RM: 154.0,
                dotsScore: 98.4,
                tier: "reforged",
                videoURL: "https://example.com/video1.mp4",
                notes: L10n.t("三停深蹲，底部停顿1秒，发力顺畅", "3-pause squat, 1s pause at the bottom, clean drive"),
                status: .certified,
                isCertified: true,
                certifiedAt: Date(),
                confirmCount: 3,
                flagCount: 0,
                visibility: .crewOnly,
                moderationStatus: "approved",
                achievedAt: Date().addingTimeInterval(-3600),
                createdAt: Date().addingTimeInterval(-3600),
                updatedAt: Date(),
                userDisplayName: L10n.t("铁牛", "Iron Bull"),
                userAvatarURL: nil,
                exerciseNameZh: "杠铃后深蹲",
                exerciseNameEn: "Barbell Back Squat"
            ),
            Proof(
                id: UUID(),
                userID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                exerciseID: UUID(),
                weightKg: 100.0,
                reps: 1,
                estimated1RM: 100.0,
                dotsScore: 68.2,
                tier: "wrought_iron",
                videoURL: "https://example.com/video2.mp4",
                notes: L10n.t("第一次推起100kg！求各位铁友验杠认证！", "First time hitting 100kg! Please witness and verify!"),
                status: .pending,
                isCertified: false,
                certifiedAt: nil,
                confirmCount: 2,
                flagCount: 0,
                visibility: .crewOnly,
                moderationStatus: "approved",
                achievedAt: Date().addingTimeInterval(-7200),
                createdAt: Date().addingTimeInterval(-7200),
                updatedAt: Date(),
                userDisplayName: L10n.t("小钢炮", "Steel Cannon"),
                userAvatarURL: nil,
                exerciseNameZh: "杠铃卧推",
                exerciseNameEn: "Barbell Bench Press"
            )
        ]
    }

    /// Fetches the feed of latest proofs (见证), filtering out blocked users
    public func fetchFeed() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: [Proof] = try await client
                .from("proofs")
                .select("""
                    *,
                    profiles!inner(display_name, avatar_url),
                    exercises!inner(name_zh)
                """)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            // Filter out content from blocked users silently (Section 4)
            self.proofs = response.filter { !self.blockService.isBlocked($0.userID) }
        } catch {
            self.errorMessage = error.localizedDescription
            // Filter local list on failure as well
            self.proofs = self.proofs.filter { !self.blockService.isBlocked($0.userID) }
        }
    }

    /// Submits a witness action (锤击见证 or 质疑标记)
    public func witnessProof(proofID: UUID, witnessID: UUID, action: WitnessAction, comment: String? = nil) async throws {
        struct WitnessPayload: Encodable {
            let proof_id: UUID
            let witness_id: UUID
            let action: String
            let comment: String?
        }

        let payload = WitnessPayload(
            proof_id: proofID,
            witness_id: witnessID,
            action: action.rawValue,
            comment: comment
        )

        try await client
            .from("witnesses")
            .insert(payload)
            .execute()

        // Refresh feed after witnessing
        await fetchFeed()
    }

    /// Submits a PR video / proof for witnessing (上铁证)
    /// Enforces crewOnly default visibility per Section 2
    public func submitProof(
        userID: UUID,
        exerciseID: UUID,
        weightKg: Double,
        reps: Int,
        estimated1RM: Double,
        dotsScore: Double,
        tier: String,
        videoURL: String? = nil,
        notes: String? = nil,
        visibility: ProofVisibility = .crewOnly
    ) async throws {
        struct ProofInsert: Encodable {
            let user_id: UUID
            let exercise_id: UUID
            let weight_kg: Double
            let reps: Int
            let estimated_1rm: Double
            let dots_score: Double
            let tier: String
            let video_url: String?
            let notes: String?
            let visibility: String
        }
        let payload = ProofInsert(
            user_id: userID,
            exercise_id: exerciseID,
            weight_kg: weightKg,
            reps: reps,
            estimated_1rm: estimated1RM,
            dots_score: dotsScore,
            tier: tier,
            video_url: videoURL,
            notes: notes,
            visibility: visibility.rawValue
        )
        try? await client
            .from("proofs")
            .insert(payload)
            .execute()

        await fetchFeed()
    }
}
