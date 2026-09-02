import Foundation
import SwiftUI

enum Sex: String, Codable, CaseIterable {
    case male, female, other

    var displayName: String {
        switch self {
        case .male: return L10n.t("男 ♂", "Male ♂")
        case .female: return L10n.t("女 ♀", "Female ♀")
        case .other: return L10n.t("其他 / 保密", "Other / Prefer not to say")
        }
    }
}

/// The four lifts that carry strength-standard rankings.
enum CoreLift: String, Codable, CaseIterable {
    case squat, bench, deadlift, ohp

    /// Matches `name_en` in the seeded exercises table (stable identifiers).
    var exerciseNameEn: String {
        switch self {
        case .squat: return "Barbell Back Squat"
        case .bench: return "Bench Press"
        case .deadlift: return "Deadlift"
        case .ohp: return "Overhead Press"
        }
    }

    var displayName: String {
        switch self {
        case .squat: return L10n.t("深蹲", "Squat")
        case .bench: return L10n.t("卧推", "Bench")
        case .deadlift: return L10n.t("硬拉", "Deadlift")
        case .ohp: return L10n.t("推举", "OHP")
        }
    }
}

/// 6 Forged Metal Tiers: 生铁 → 熟铁 → 铸钢 → 精钢 → 重锻 → 百炼
/// Defined in IRODENCE_PALETTE.md & IRODENCE_DESIGN.md.
enum StrengthTier: Int, CaseIterable, Comparable, Codable {
    case pigIron = 0       // 生铁 (Pig Iron)
    case wroughtIron = 1   // 熟铁 (Wrought Iron)
    case castSteel = 2     // 铸钢 (Cast Steel)
    case refinedSteel = 3  // 精钢 (Refined Steel)
    case reforged = 4      // 重锻 (Reforged Steel)
    case hundredFold = 5   // 百炼 (Masterwork Steel)

    static func < (lhs: StrengthTier, rhs: StrengthTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .pigIron: return L10n.t("生铁", "Pig Iron")
        case .wroughtIron: return L10n.t("熟铁", "Wrought Iron")
        case .castSteel: return L10n.t("铸钢", "Cast Steel")
        case .refinedSteel: return L10n.t("精钢", "Refined Steel")
        case .reforged: return L10n.t("重锻", "Reforged Steel")
        case .hundredFold: return L10n.t("百炼", "Masterwork")
        }
    }

    var dbValue: String {
        switch self {
        case .pigIron: return "pig_iron"
        case .wroughtIron: return "wrought_iron"
        case .castSteel: return "cast_steel"
        case .refinedSteel: return "refined_steel"
        case .reforged: return "reforged"
        case .hundredFold: return "hundred_fold"
        }
    }

    init?(dbValue: String) {
        switch dbValue {
        case "pig_iron": self = .pigIron
        case "wrought_iron": self = .wroughtIron
        case "cast_steel", "dark_steel": self = .castSteel
        case "refined_steel": self = .refinedSteel
        case "reforged": self = .reforged
        case "hundred_fold", "meteoric_iron": self = .hundredFold
        default: return nil
        }
    }

    var color: Color {
        switch self {
        case .pigIron: return Theme.Colors.tierPigIron
        case .wroughtIron: return Theme.Colors.tierWroughtIron
        case .castSteel: return Theme.Colors.tierCastSteel
        case .refinedSteel: return Theme.Colors.tierRefinedSteel
        case .reforged: return Theme.Colors.tierReforged
        case .hundredFold: return Theme.Colors.tierHundredFold
        }
    }

    var systemImage: String {
        switch self {
        case .pigIron: return "circle.grid.cross.fill"
        case .wroughtIron: return "shield.fill"
        case .castSteel: return "seal.fill"
        case .refinedSteel: return "shield.lefthalf.filled"
        case .reforged: return "hammer.fill"
        case .hundredFold: return "sparkles"
        }
    }

    var assetImageName: String {
        switch self {
        case .pigIron: return "tier_pig_iron"
        case .wroughtIron: return "tier_wrought_iron"
        case .castSteel: return "tier_cast_steel"
        case .refinedSteel: return "tier_refined_steel"
        case .reforged: return "tier_reforged"
        case .hundredFold: return "tier_hundred_fold"
        }
    }
}

/// DOTS (Dynamic Objective Total Scoring) — modern replacement for Wilks.
/// Score = liftedKg * 500 / polynomial(bodyweight), separate coefficient
/// sets per sex, so scores are comparable across sex and bodyweight.
enum DOTSCalculator {
    /// Official DOTS coefficients [a0...a4], denominator = Σ ai·bw^i.
    private static let coefficients: [Sex: [Double]] = [
        .male:   [-307.75076, 24.0900756, -0.1918759221, 0.0007391293, -0.000001093],
        .female: [-57.96288, 13.6175032, -0.1126655495, 0.0005158568, -0.0000010706],
        .other:  [-307.75076, 24.0900756, -0.1918759221, 0.0007391293, -0.000001093],
    ]

    /// Bodyweight outside this range is clamped (per DOTS convention).
    private static let bodyweightRange: ClosedRange<Double> = 40...210

    /// Reference height baseline (cm): 175cm male / 162cm female
    private static let referenceHeightCm: [Sex: Double] = [
        .male: 175.0,
        .female: 162.0,
        .other: 170.0
    ]

    static func score(
        liftedKg: Double,
        bodyweightKg: Double,
        sex: Sex,
        heightCm: Double? = nil,
        ageYears: Int? = nil
    ) -> Double {
        guard liftedKg > 0 else { return 0 }
        let bw = min(max(bodyweightKg, bodyweightRange.lowerBound), bodyweightRange.upperBound)
        let c = coefficients[sex] ?? coefficients[.male]!
        let denom = c[0] + c[1] * bw + c[2] * pow(bw, 2) + c[3] * pow(bw, 3) + c[4] * pow(bw, 4)
        guard denom > 0 else { return 0 }

        var baseScore = liftedKg * 500 / denom

        // 1. Height Correction Factor (Range of Motion / Work = Force × Distance)
        if let heightCm, heightCm > 100, heightCm < 250 {
            let refHeight = referenceHeightCm[sex] ?? 175.0
            let heightFactor = pow(heightCm / refHeight, 0.12)
            baseScore *= heightFactor
        }

        // 2. Age Correction Factor (IPF/McCulloch Master Age Multiplier)
        if let ageYears {
            if ageYears >= 40 {
                // ~0.8% score boost per year above 39 to compensate for natural age-related strength decline
                let ageFactor = 1.0 + 0.008 * Double(ageYears - 39)
                baseScore *= min(ageFactor, 1.45)
            } else if ageYears > 0 && ageYears < 23 {
                // Junior age adjustment for developing athletes (<23)
                let ageFactor = 1.0 + 0.005 * Double(23 - ageYears)
                baseScore *= min(ageFactor, 1.12)
            }
        }

        return baseScore
    }
}

/// Maps DOTS scores to 生铁→熟铁→铸钢→精钢→重锻→百炼 tiers, per lift and sex.
enum StrengthStandards {

    // Tier boundaries as DOTS scores for 5 transition points (dividing into 6 tiers):
    // [熟铁 starts, 铸钢 starts, 精钢 starts, 重锻 starts, 百炼 starts]
    // Calibrated for encouraging, realistic natural strength progression:
    private static let thresholds: [CoreLift: [Sex: [Double]]] = [
        .squat:    [.male: [45, 75, 108, 142, 175], .female: [35, 58, 85, 112, 140], .other: [40, 66, 96, 127, 157]],
        .bench:    [.male: [30, 52, 78, 105, 132],  .female: [18, 32, 50, 70, 92],    .other: [24, 42, 64, 88, 112]],
        .deadlift: [.male: [55, 88, 122, 158, 192], .female: [42, 68, 96, 126, 155], .other: [48, 78, 109, 142, 173]],
        .ohp:      [.male: [18, 30, 44, 58, 72],    .female: [12, 22, 34, 46, 58],    .other: [15, 26, 39, 52, 65]],
    ]

    static func tier(for dots: Double, lift: CoreLift, sex: Sex) -> StrengthTier {
        let bounds = thresholds[lift]?[sex] ?? thresholds[lift]?[.male]! ?? [45, 75, 108, 142, 175]
        var tier = StrengthTier.pigIron
        for (index, boundary) in bounds.enumerated() where dots >= boundary {
            tier = StrengthTier(rawValue: index + 1) ?? .hundredFold
        }
        return tier
    }

    /// Computes the overall unified strength tier for a total DOTS score across tracked lifts.
    static func overallTier(totalDots: Double, liftsCount: Int = 4, sex: Sex) -> StrengthTier {
        guard totalDots > 0, liftsCount > 0 else { return .pigIron }

        // Average of [.squat, .bench, .deadlift, .ohp] transition thresholds
        let averageBounds: [Double]
        switch sex {
        case .male:
            // 熟铁: 37.0, 铸钢: 61.25, 精钢: 88.0, 重锻: 115.75, 百炼: 142.75
            averageBounds = [37.0, 61.25, 88.0, 115.75, 142.75]
        case .female:
            // 熟铁: 26.75, 铸钢: 45.0, 精钢: 66.25, 重锻: 88.5, 百炼: 111.25
            averageBounds = [26.75, 45.0, 66.25, 88.5, 111.25]
        case .other:
            // 熟铁: 31.75, 铸钢: 53.0, 精钢: 77.0, 重锻: 102.25, 百炼: 126.75
            averageBounds = [31.75, 53.0, 77.0, 102.25, 126.75]
        }

        let avgDots = totalDots / Double(liftsCount)
        var tier = StrengthTier.pigIron
        for (index, boundary) in averageBounds.enumerated() where avgDots >= boundary {
            tier = StrengthTier(rawValue: index + 1) ?? .hundredFold
        }
        return tier
    }

    /// Computes overall tier directly from individual core lift bests with forgiving athletic aggregation.
    static func overallTier(
        bestLifts: [CoreLift: (est1RM: Double, weightKg: Double, reps: Int)],
        bodyweightKg: Double,
        sex: Sex,
        heightCm: Double? = nil,
        ageYears: Int? = nil
    ) -> StrengthTier {
        guard !bestLifts.isEmpty else { return .pigIron }
        var liftTiers: [StrengthTier] = []
        var totalTierProgress = 0.0

        for (lift, best) in bestLifts {
            let dots = DOTSCalculator.score(liftedKg: best.est1RM, bodyweightKg: bodyweightKg, sex: sex, heightCm: heightCm, ageYears: ageYears)
            let liftTier = tier(for: dots, lift: lift, sex: sex)
            let (_, progress, _) = progressToNextTier(dots: dots, lift: lift, sex: sex)
            liftTiers.append(liftTier)
            totalTierProgress += Double(liftTier.rawValue) + progress
        }

        // Forgiving rule: If the majority (>= 50%) of tracked lifts reach or exceed a tier, guarantee that tier
        let sortedTiers = liftTiers.sorted()
        let medianTier = sortedTiers[sortedTiers.count / 2]

        let avgTierScore = totalTierProgress / Double(bestLifts.count)
        // Friendly round-up for dedicated athletes making solid progress
        let roundedTierIndex = min(max(Int(avgTierScore + 0.15), 0), StrengthTier.hundredFold.rawValue)
        let calculatedTier = StrengthTier(rawValue: roundedTierIndex) ?? .pigIron

        return max(medianTier, calculatedTier)
    }

    /// Progress (0...1) from the current tier toward the next, plus the DOTS
    /// score needed to reach it (nil if already hundredFold).
    static func progressToNextTier(dots: Double, lift: CoreLift, sex: Sex)
        -> (tier: StrengthTier, progress: Double, nextBoundary: Double?)
    {
        let bounds = thresholds[lift]?[sex] ?? thresholds[lift]?[.male]! ?? [50, 80, 110, 140, 170]
        let tier = tier(for: dots, lift: lift, sex: sex)
        guard tier != .hundredFold else { return (tier, 1, nil) }

        let lower = tier == .pigIron ? 0 : bounds[tier.rawValue - 1]
        let upper = bounds[tier.rawValue]
        let progress = upper > lower ? min(max((dots - lower) / (upper - lower), 0), 1) : 0
        return (tier, progress, upper)
    }
}

// MARK: - Comprehensive Global Exercise Strength Standards Engine

/// Realistic 6-tier strength standards ladder for EVERY exercise in the library.
/// Based on empirical powerlifting, weightlifting, and hypertrophy benchmarks (ExRx / StrengthLevel)
/// scaled via allometric bodyweight exponents (bw^0.67) and sex baselines.
struct ExerciseLadderTier: Identifiable, Hashable {
    let id = UUID()
    let tier: StrengthTier
    let minWeightKg: Double
    let maxWeightKg: Double?
    let label: String
}

enum ExerciseStrengthStandards {

    /// Unit display for exercise standard weights (e.g. "kg", "kg/手", "+kg")
    static func unitLabel(for exercise: Exercise) -> String {
        switch exercise.equipment {
        case .dumbbell:
            return L10n.t("kg/手", "kg/hand")
        case .bodyweight:
            return L10n.t("+kg 负重", "+kg load")
        default:
            return "kg"
        }
    }

    /// Pre-calibrated empirical 5-threshold baselines [熟铁, 铸钢, 精钢, 重锻, 百炼]
    /// normalized for 75kg male / 60kg female reference athletes.
    private struct BenchmarkSpec {
        let male75kg: [Double]
        let female60kg: [Double]
    }

    private static let benchmarkDatabase: [String: BenchmarkSpec] = [
        // Squat & Lower Body Compound
        "Barbell Back Squat": BenchmarkSpec(
            male75kg: [65, 95, 125, 155, 185],
            female60kg: [38, 55, 75, 98, 120]
        ),
        "Leg Press": BenchmarkSpec(
            male75kg: [150, 220, 300, 380, 460],
            female60kg: [90, 140, 200, 260, 320]
        ),
        "Hip Thrust": BenchmarkSpec(
            male75kg: [70, 110, 150, 190, 230],
            female60kg: [50, 80, 115, 150, 185]
        ),
        "Romanian Deadlift": BenchmarkSpec(
            male75kg: [60, 95, 130, 165, 200],
            female60kg: [35, 55, 80, 110, 140]
        ),
        "Deadlift": BenchmarkSpec(
            male75kg: [75, 110, 145, 180, 215],
            female60kg: [45, 68, 92, 118, 145]
        ),

        // Upper Body Compound (Presses & Pulls)
        "Bench Press": BenchmarkSpec(
            male75kg: [50, 75, 100, 125, 150],
            female60kg: [25, 38, 52, 68, 85]
        ),
        "Overhead Press": BenchmarkSpec(
            male75kg: [32, 48, 64, 80, 95],
            female60kg: [18, 26, 36, 48, 60]
        ),
        "Barbell Row": BenchmarkSpec(
            male75kg: [45, 68, 90, 115, 138],
            female60kg: [25, 38, 52, 68, 85]
        ),
        "Lat Pulldown": BenchmarkSpec(
            male75kg: [40, 58, 78, 98, 118],
            female60kg: [25, 36, 50, 65, 80]
        ),
        "Incline Dumbbell Press": BenchmarkSpec(
            male75kg: [14, 22, 32, 42, 52],
            female60kg: [8, 12, 18, 24, 30]
        ),

        // Calisthenics (+added weight or equivalent)
        "Pull-up": BenchmarkSpec(
            male75kg: [0, 10, 25, 42, 60],
            female60kg: [0, 4, 12, 22, 34]
        ),
        "Dips": BenchmarkSpec(
            male75kg: [0, 15, 32, 52, 72],
            female60kg: [0, 6, 16, 28, 42]
        ),

        // Isolations (Arms, Delts, Legs, Core)
        "Dumbbell Lateral Raise": BenchmarkSpec(
            male75kg: [5, 8, 12, 16, 22],
            female60kg: [2.5, 4, 6, 9, 12]
        ),
        "Barbell Biceps Curl": BenchmarkSpec(
            male75kg: [20, 30, 42, 55, 68],
            female60kg: [10, 16, 22, 30, 38]
        ),
        "Triceps Pushdown": BenchmarkSpec(
            male75kg: [20, 32, 45, 60, 75],
            female60kg: [12, 18, 26, 36, 46]
        ),
        "Leg Extension": BenchmarkSpec(
            male75kg: [35, 55, 78, 102, 128],
            female60kg: [20, 32, 46, 62, 80]
        ),
        "Leg Curl": BenchmarkSpec(
            male75kg: [30, 48, 68, 90, 112],
            female60kg: [18, 28, 40, 54, 70]
        ),
        "Standing Calf Raise": BenchmarkSpec(
            male75kg: [50, 85, 125, 168, 215],
            female60kg: [30, 52, 78, 108, 140]
        ),
        "Cable Woodchopper": BenchmarkSpec(
            male75kg: [15, 24, 35, 48, 62],
            female60kg: [8, 14, 20, 28, 38]
        ),
        "Face Pull": BenchmarkSpec(
            male75kg: [15, 25, 38, 52, 66],
            female60kg: [8, 14, 22, 30, 40]
        )
    ]

    /// Dynamically computes the 5 threshold boundary weights [熟铁, 铸钢, 精钢, 重锻, 百炼]
    /// for any exercise, tailored to the user's sex and bodyweight.
    static func thresholds(for exercise: Exercise, sex: Sex, bodyweightKg: Double) -> [Double] {
        let bw = min(max(bodyweightKg, 40), 160)
        let refBw = sex == .female ? 60.0 : 75.0
        // Allometric dimensional scaling factor (forces scale with muscle cross-section area ~ bw^0.67)
        let scaleFactor = pow(bw / refBw, 0.67)

        let baseBounds: [Double]
        if let spec = benchmarkDatabase[exercise.nameEn] {
            baseBounds = sex == .female ? spec.female60kg : spec.male75kg
        } else {
            // Intelligent Biomechanical Fallback Profiler for custom/unmapped exercises
            baseBounds = fallbackBaseBounds(for: exercise, sex: sex)
        }

        return baseBounds.map { raw in
            let scaled = raw * scaleFactor
            return roundWeight(scaled, equipment: exercise.equipment)
        }
    }

    /// Determines the lifter's achieved StrengthTier for this exercise.
    static func tier(for weightKg: Double, exercise: Exercise, sex: Sex, bodyweightKg: Double) -> StrengthTier {
        guard weightKg > 0 else { return .pigIron }
        let bounds = thresholds(for: exercise, sex: sex, bodyweightKg: bodyweightKg)

        var tier = StrengthTier.pigIron
        for (index, boundary) in bounds.enumerated() where weightKg >= boundary {
            tier = StrengthTier(rawValue: index + 1) ?? .hundredFold
        }
        return tier
    }

    /// Computes percentage progress (0...1) from current tier to next tier and the weight gap.
    static func progress(
        for weightKg: Double,
        exercise: Exercise,
        sex: Sex,
        bodyweightKg: Double
    ) -> (tier: StrengthTier, progress: Double, nextTargetKg: Double?, currentTierMinKg: Double) {
        let bounds = thresholds(for: exercise, sex: sex, bodyweightKg: bodyweightKg)
        let current = tier(for: weightKg, exercise: exercise, sex: sex, bodyweightKg: bodyweightKg)

        let currentMin: Double
        if current == .pigIron {
            currentMin = 0
        } else {
            currentMin = bounds[current.rawValue - 1]
        }

        guard current != .hundredFold else {
            return (current, 1.0, nil, currentMin)
        }

        let nextBoundary = bounds[current.rawValue]
        let span = nextBoundary - currentMin
        let progress = span > 0 ? min(max((weightKg - currentMin) / span, 0.0), 1.0) : 0.0

        return (current, progress, nextBoundary, currentMin)
    }

    /// Full 6-tier ladder metadata for UI presentation.
    static func ladder(for exercise: Exercise, sex: Sex, bodyweightKg: Double) -> [ExerciseLadderTier] {
        let bounds = thresholds(for: exercise, sex: sex, bodyweightKg: bodyweightKg)

        var result: [ExerciseLadderTier] = []
        for tier in StrengthTier.allCases {
            let minWeight: Double
            let maxWeight: Double?
            let label: String

            switch tier {
            case .pigIron:
                minWeight = 0
                maxWeight = bounds[0]
                label = L10n.t("初入铁砧，建立基础力量与标准动作轨迹", "Novice — baseline strength and learning form")
            case .wroughtIron:
                minWeight = bounds[0]
                maxWeight = bounds[1]
                label = L10n.t("淬炼成型，动作稳健并开启稳定渐进负荷", "Early Intermediate — steady progression")
            case .castSteel:
                minWeight = bounds[1]
                maxWeight = bounds[2]
                label = L10n.t("扎实坚韧，达到经常健身的扎实铁友水准", "Intermediate — solid gym regular standard")
            case .refinedSteel:
                minWeight = bounds[2]
                maxWeight = bounds[3]
                label = L10n.t("千锤百炼，远超普通训练者的高阶强悍水平", "Advanced — well above average gym lifter")
            case .reforged:
                minWeight = bounds[3]
                maxWeight = bounds[4]
                label = L10n.t("重构极限，跻身竞技比赛级顶尖实力", "Elite — competitive lifter strength")
            case .hundredFold:
                minWeight = bounds[4]
                maxWeight = nil
                label = L10n.t("百炼纯钢，领奖台与殿堂级传奇力量", "Masterwork — world-class podium strength")
            }

            result.append(ExerciseLadderTier(
                tier: tier,
                minWeightKg: minWeight,
                maxWeightKg: maxWeight,
                label: label
            ))
        }

        return result
    }

    // MARK: - Internal Fallback Generator for Custom Exercises

    private static func fallbackBaseBounds(for exercise: Exercise, sex: Sex) -> [Double] {
        let femaleRatio = 0.62
        let maleBounds: [Double]

        switch (exercise.equipment, exercise.primaryMuscle, exercise.isCompound) {
        case (.dumbbell, _, true):
            // Dumbbell Compound (e.g. DB Press, DB Squat)
            maleBounds = [12, 20, 28, 38, 48]
        case (.dumbbell, _, false):
            // Dumbbell Isolation (e.g. DB Fly, DB Curl)
            maleBounds = [6, 10, 15, 20, 26]
        case (.barbell, .quads, _), (.barbell, .glutes, _):
            // Barbell Legs
            maleBounds = [60, 90, 120, 150, 180]
        case (.barbell, .back, _), (.barbell, .hamstrings, _):
            // Barbell Pull
            maleBounds = [55, 85, 115, 145, 175]
        case (.barbell, _, _):
            // Barbell Upper
            maleBounds = [40, 65, 90, 115, 140]
        case (.machine, .quads, true), (.machine, .glutes, true):
            // Machine Leg Compound (Hack Squat / Leg Press)
            maleBounds = [100, 160, 230, 300, 380]
        case (.machine, _, _), (.cable, _, _):
            // Machine & Cable Upper / Isolations
            maleBounds = [25, 40, 58, 78, 100]
        case (.bodyweight, _, _):
            // Bodyweight
            maleBounds = [0, 10, 24, 40, 58]
        }

        if sex == .female {
            return maleBounds.map { $0 * femaleRatio }
        }
        return maleBounds
    }

    private static func roundWeight(_ value: Double, equipment: Equipment) -> Double {
        if equipment == .dumbbell {
            // Dumbbells usually increment by 1kg or 2kg
            return (value * 2).rounded() / 2
        } else if equipment == .bodyweight {
            return value.rounded()
        } else {
            // Barbell & machines round to nearest 2.5kg or 5kg
            return (value / 2.5).rounded() * 2.5
        }
    }
}
