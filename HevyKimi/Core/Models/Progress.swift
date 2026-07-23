import Foundation

/// Row in `public.bodyweight_logs`.
struct BodyweightLog: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let weightKg: Double
    let loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case weightKg = "weight_kg"
        case loggedAt = "logged_at"
    }
}

/// One point on the per-exercise est-1RM history chart: the best Epley
/// estimate of that day.
struct StrengthHistoryPoint: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let estimated1RM: Double
}
