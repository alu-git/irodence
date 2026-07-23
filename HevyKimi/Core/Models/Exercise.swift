import Foundation

/// An exercise in the global library. Maps 1:1 to `public.exercises`.
struct Exercise: Identifiable, Codable, Hashable {
    let id: UUID
    let nameEn: String
    let nameZh: String
    let primaryMuscle: MuscleGroup
    let equipment: Equipment
    let isCompound: Bool
    let instructions: String?

    enum CodingKeys: String, CodingKey {
        case id
        case nameEn = "name_en"
        case nameZh = "name_zh"
        case primaryMuscle = "primary_muscle"
        case equipment
        case isCompound = "is_compound"
        case instructions
    }

    /// Display name — Simplified Chinese is the primary UI language.
    var displayName: String { nameZh }
}

enum MuscleGroup: String, Codable, CaseIterable {
    case chest, back, shoulders, quads, hamstrings, glutes
    case biceps, triceps, calves, core

    var displayName: String {
        switch self {
        case .chest: return "胸"
        case .back: return "背"
        case .shoulders: return "肩"
        case .quads: return "股四头肌"
        case .hamstrings: return "腘绳肌"
        case .glutes: return "臀"
        case .biceps: return "肱二头肌"
        case .triceps: return "肱三头肌"
        case .calves: return "小腿"
        case .core: return "核心"
        }
    }
}

enum Equipment: String, Codable, CaseIterable {
    case barbell, dumbbell, machine, cable, bodyweight

    var displayName: String {
        switch self {
        case .barbell: return "杠铃"
        case .dumbbell: return "哑铃"
        case .machine: return "器械"
        case .cable: return "绳索"
        case .bodyweight: return "自重"
        }
    }
}
