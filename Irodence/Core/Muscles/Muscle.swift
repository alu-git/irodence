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
        case .chest: return L10n.t("胸", "Chest")
        case .obliques: return L10n.t("腹斜肌", "Obliques")
        case .abs: return L10n.t("腹直肌", "Abs")
        case .biceps: return L10n.t("肱二头肌", "Biceps")
        case .triceps: return L10n.t("肱三头肌", "Triceps")
        case .neck: return L10n.t("颈", "Neck")
        case .trapezius: return L10n.t("斜方肌", "Traps")
        case .deltoids: return L10n.t("三角肌", "Delts")
        case .adductors: return L10n.t("内收肌", "Adductors")
        case .quadriceps: return L10n.t("股四头肌", "Quads")
        case .knees: return L10n.t("膝", "Knees")
        case .tibialis: return L10n.t("胫骨前肌", "Tibialis")
        case .calves: return L10n.t("小腿", "Calves")
        case .forearm: return L10n.t("前臂", "Forearms")
        case .hands: return L10n.t("手", "Hands")
        case .ankles: return L10n.t("踝", "Ankles")
        case .feet: return L10n.t("足", "Feet")
        case .head: return L10n.t("头", "Head")
        case .hair: return L10n.t("头发", "Hair")
        case .upperBack: return L10n.t("上背", "Upper Back")
        case .lowerBack: return L10n.t("下背", "Lower Back")
        case .gluteal: return L10n.t("臀", "Glutes")
        case .hamstring: return L10n.t("腘绳肌", "Hamstrings")
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
