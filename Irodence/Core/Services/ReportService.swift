import Foundation
import Supabase

/// Categories for reporting content or users per IRODENCE_SAFETY.md Section 4 & 5.
public enum ReportReason: String, CaseIterable, Identifiable, Codable {
    case harassment = "harassment"
    case cheating = "cheating"
    case injury = "injury"
    case minor = "minor"
    case inappropriate = "inappropriate"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .harassment:
            return L10n.t("骚扰、侮辱或不当言行 (24小时优先响应)", "Harassment or Inappropriate Contact (<24h priority)")
        case .cheating:
            return L10n.t("作弊、虚假重量或假片假杠", "Cheating, Fake Weight or Fake Plates")
        case .injury:
            return L10n.t("危险动作、严重伤病或失控砸杠", "Dangerous Lift, Injury or Unsafe Attempt")
        case .minor:
            return L10n.t("未成年人涉身视频", "Minor Safety Violation")
        case .inappropriate:
            return L10n.t("违法违规或无关内容", "Illegal, Spam or Inappropriate Content")
        }
    }

    public var priority: String {
        switch self {
        case .harassment, .minor: return "high"
        case .injury: return "urgent"
        case .cheating, .inappropriate: return "normal"
        }
    }
}

/// Service handling moderation reports and routing per IRODENCE_SAFETY.md.
@MainActor
public final class ReportService: ObservableObject {
    public static let shared = ReportService()

    private let client = SupabaseService.client

    public init() {}

    /// Submits a moderation report for a proof or user
    public func submitReport(
        reporterID: UUID,
        targetProofID: UUID?,
        targetUserID: UUID,
        reason: ReportReason,
        details: String?
    ) async throws {
        struct ReportPayload: Encodable {
            let reporter_id: UUID
            let target_proof_id: UUID?
            let target_user_id: UUID
            let reason: String
            let priority: String
            let details: String?
            let created_at: Date
        }

        let payload = ReportPayload(
            reporter_id: reporterID,
            target_proof_id: targetProofID,
            target_user_id: targetUserID,
            reason: reason.rawValue,
            priority: reason.priority,
            details: details,
            created_at: Date()
        )

        try await client
            .from("moderation_reports")
            .insert(payload)
            .execute()
    }
}
