import Foundation

/// A ready-made workout template shipped with the app (not stored in
/// Supabase). Exercises are referenced by their English name and resolved
/// against the loaded library at start time — new seed exercises become
/// available automatically.
struct BuiltInTemplate: Identifiable {
    let name: String
    let subtitle: String
    let systemImage: String
    /// Pairs of (exercise nameEn, superset group); same non-nil group = superset.
    let items: [(nameEn: String, supersetGroup: Int?)]

    var id: String { name }

    static let upperDay = BuiltInTemplate(
        name: L10n.t("上肢日", "Upper Day"),
        subtitle: L10n.t("胸 · 背 · 肩 · 手臂", "Chest · Back · Shoulders · Arms"),
        systemImage: "figure.strengthtraining.traditional",
        items: [
            ("Bench Press", nil),
            ("Barbell Row", nil),
            ("Overhead Press", nil),
            ("Lat Pulldown", nil),
            ("Incline Dumbbell Press", nil),
            ("Bicep Curl", 1),
            ("Tricep Pushdown", 1),
        ]
    )

    static let all: [BuiltInTemplate] = [.upperDay]
}
