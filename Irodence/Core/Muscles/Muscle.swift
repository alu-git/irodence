import Foundation

/// Muscle groups matching the slugs in react-native-body-highlighter's
/// geometry data. Trainable muscles plus structural parts (head, hair,
/// knees, hands, etc.) that exist in the source artwork but are never
/// highlighted as "trained".
enum Muscle: String, CaseIterable, Codable, Hashable {
    case chest, obliques, abs, biceps, triceps, neck, trapezius, deltoids
    case adductors, quadriceps, knees, tibialis, calves, forearm, hands
    case ankles, feet, head, hair
    case upperBack, lowerBack, gluteal, hamstring

    /// Muscles that map to real training targets (excludes hair, head, etc.).
    static let trainable: Set<Muscle> = [
        .chest, .obliques, .abs, .biceps, .triceps, .neck, .trapezius,
        .deltoids, .adductors, .quadriceps, .tibialis, .calves, .forearm,
        .upperBack, .lowerBack, .gluteal, .hamstring,
    ]

    var displayName: String {
        switch self {
        case .chest: return "胸"
        case .obliques: return "腹斜肌"
        case .abs: return "腹直肌"
        case .biceps: return "肱二头肌"
        case .triceps: return "肱三头肌"
        case .neck: return "颈"
        case .trapezius: return "斜方肌"
        case .deltoids: return "三角肌"
        case .adductors: return "内收肌"
        case .quadriceps: return "股四头肌"
        case .knees: return "膝"
        case .tibialis: return "胫骨前肌"
        case .calves: return "小腿"
        case .forearm: return "前臂"
        case .hands: return "手"
        case .ankles: return "踝"
        case .feet: return "足"
        case .head: return "头"
        case .hair: return "头发"
        case .upperBack: return "上背"
        case .lowerBack: return "下背"
        case .gluteal: return "臀"
        case .hamstring: return "腘绳肌"
        }
    }
}

/// Maps free-exercise-db muscle strings (used by the exercise library
/// schema) to Muscle cases.
extension Muscle {
    /// free-exercise-db uses e.g. "lats", "middle back", "abdominals".
    init?(freeExerciseDBName name: String) {
        switch name.lowercased() {
        case "chest": self = .chest
        case "abdominals": self = .abs
        case "obliques": self = .obliques  // not in free-exercise-db core list, kept for safety
        case "biceps": self = .biceps
        case "triceps": self = .triceps
        case "neck": self = .neck
        case "traps": self = .trapezius
        case "shoulders": self = .deltoids
        case "adductors": self = .adductors
        case "abductors": self = .gluteal  // closest match; no abductor artwork in source data
        case "quadriceps": self = .quadriceps
        case "calves": self = .calves
        case "forearms": self = .forearm
        case "lats", "middle back": self = .upperBack
        case "lower back": self = .lowerBack
        case "glutes": self = .gluteal
        case "hamstrings": self = .hamstring
        default: return nil
        }
    }

    /// Converts free-exercise-db primary/secondary arrays into a highlight set.
    static func fromExercise(primary: [String], secondary: [String]) -> Set<Muscle> {
        Set(primary.compactMap { Muscle(freeExerciseDBName: $0) })
            .union(secondary.compactMap { Muscle(freeExerciseDBName: $0) })
    }
}

/// Maps the app's own MuscleGroup (seeded library schema) to diagram muscles.
extension MuscleGroup {
    var diagramMuscles: Set<Muscle> {
        switch self {
        case .chest: return [.chest]
        case .back: return [.upperBack, .lowerBack, .trapezius]
        case .shoulders: return [.deltoids, .trapezius]
        case .quads: return [.quadriceps]
        case .hamstrings: return [.hamstring]
        case .glutes: return [.gluteal]
        case .biceps: return [.biceps]
        case .triceps: return [.triceps]
        case .calves: return [.calves, .tibialis]
        case .core: return [.abs, .obliques]
        }
    }
}
