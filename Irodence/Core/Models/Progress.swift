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

/// One point on the per-exercise history chart: best est-1RM and max weight of that day.
struct StrengthHistoryPoint: Identifiable, Codable, Hashable {
    var id: Date { date }
    let date: Date
    let estimated1RM: Double
    let maxWeight: Double
}

/// Row in `public.progress_photos`. The image itself lives in the private
/// `progress-photos` storage bucket at `storagePath`; clients view it via a
/// time-limited signed URL.
struct ProgressPhoto: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let storagePath: String
    let note: String?
    let takenAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case storagePath = "storage_path"
        case note
        case takenAt = "taken_at"
    }
}
