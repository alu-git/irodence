import Foundation

/// An exercise in the global library. Maps 1:1 to `public.exercises`.
struct Exercise: Identifiable, Codable, Hashable {
    let id: UUID
    let nameEn: String
    let nameZh: String
    let primaryMuscle: MuscleGroup
    let equipment: Equipment
    let isCompound: Bool
    let instructionsZh: String?
    let instructionsEn: String?
    /// How a set of this exercise is logged (weight+reps / reps only / timer).
    var trackingMode: TrackingMode = .weighted

    enum CodingKeys: String, CodingKey {
        case id
        case nameEn = "name_en"
        case nameZh = "name_zh"
        case primaryMuscle = "primary_muscle"
        case equipment
        case isCompound = "is_compound"
        case instructionsZh = "instructions_zh"
        case instructionsEn = "instructions_en"
        case trackingMode = "tracking_mode"
    }

    /// Tolerant decode: rows missing `tracking_mode` (migration not yet
    /// applied) fall back to `.weighted` instead of failing the whole fetch.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        nameEn = try c.decode(String.self, forKey: .nameEn)
        nameZh = try c.decode(String.self, forKey: .nameZh)
        primaryMuscle = try c.decode(MuscleGroup.self, forKey: .primaryMuscle)
        equipment = try c.decode(Equipment.self, forKey: .equipment)
        isCompound = try c.decode(Bool.self, forKey: .isCompound)
        instructionsZh = try c.decodeIfPresent(String.self, forKey: .instructionsZh)
        instructionsEn = try c.decodeIfPresent(String.self, forKey: .instructionsEn)
        trackingMode = try c.decodeIfPresent(TrackingMode.self, forKey: .trackingMode) ?? .weighted
    }

    /// Explicit memberwise init (the custom decoder init above suppresses
    /// the synthesized one; previews/mocks construct exercises directly).
    init(id: UUID, nameEn: String, nameZh: String, primaryMuscle: MuscleGroup,
         equipment: Equipment, isCompound: Bool,
         instructionsZh: String? = nil, instructionsEn: String? = nil,
         trackingMode: TrackingMode = .weighted) {
        self.id = id
        self.nameEn = nameEn
        self.nameZh = nameZh
        self.primaryMuscle = primaryMuscle
        self.equipment = equipment
        self.isCompound = isCompound
        self.instructionsZh = instructionsZh
        self.instructionsEn = instructionsEn
        self.trackingMode = trackingMode
    }

    /// Display name — follows the in-app language setting (中文 default).
    var displayName: String {
        AppLanguage.isEnglish ? nameEn : nameZh
    }

    /// Primary name (large) — native language name
    var primaryName: String {
        AppLanguage.isEnglish ? nameEn : nameZh
    }

    /// Secondary name (small) — opposite language name
    var secondaryName: String {
        AppLanguage.isEnglish ? nameZh : nameEn
    }

    /// Localized instructions based on current language
    var instructions: String? {
        AppLanguage.isEnglish ? instructionsEn : instructionsZh
    }
}

/// How a set is logged for an exercise.
enum TrackingMode: String, Codable, CaseIterable {
    case weighted    // weight + reps
    case bodyweight  // reps only
    case duration    // timed (planks, cardio)

    var usesWeight: Bool { self == .weighted }
    var usesReps: Bool { self != .duration }
}

enum MuscleGroup: String, Codable, CaseIterable {
    case chest, back, shoulders, quads, hamstrings, glutes
    case biceps, triceps, calves, core

    var displayName: String {
        switch self {
        case .chest: return L10n.t("胸", "Chest")
        case .back: return L10n.t("背", "Back")
        case .shoulders: return L10n.t("肩", "Shoulders")
        case .quads: return L10n.t("股四头肌", "Quads")
        case .hamstrings: return L10n.t("腘绳肌", "Hamstrings")
        case .glutes: return L10n.t("臀", "Glutes")
        case .biceps: return L10n.t("肱二头肌", "Biceps")
        case .triceps: return L10n.t("肱三头肌", "Triceps")
        case .calves: return L10n.t("小腿", "Calves")
        case .core: return L10n.t("核心", "Core")
        }
    }

    /// Maps the muscle group to the anatomical muscles from open-source react-native-body-highlighter geometry.
    var anatomicalMuscles: Set<Muscle> {
        switch self {
        case .chest: return [.chest]
        case .back: return [.upperBack, .lowerBack, .trapezius]
        case .shoulders: return [.deltoids]
        case .quads: return [.quadriceps]
        case .hamstrings: return [.hamstring]
        case .glutes: return [.gluteal]
        case .biceps: return [.biceps]
        case .triceps: return [.triceps]
        case .calves: return [.calves]
        case .core: return [.abs, .obliques]
        }
    }
}

enum Equipment: String, Codable, CaseIterable {
    case barbell, dumbbell, machine, cable, bodyweight

    var displayName: String {
        switch self {
        case .barbell: return L10n.t("杠铃", "Barbell")
        case .dumbbell: return L10n.t("哑铃", "Dumbbell")
        case .machine: return L10n.t("器械", "Machine")
        case .cable: return L10n.t("绳索", "Cable")
        case .bodyweight: return L10n.t("自重", "Bodyweight")
        }
    }
}
