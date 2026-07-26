import Foundation
import SwiftUI

enum Sex: String, Codable, CaseIterable {
    case male, female

    var displayName: String {
        switch self {
        case .male: return L10n.t("男", "Male")
        case .female: return L10n.t("女", "Female")
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

enum StrengthTier: Int, CaseIterable, Comparable {
    case novice = 0, beginner, intermediate, advanced, elite

    static func < (lhs: StrengthTier, rhs: StrengthTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .novice: return L10n.t("新手", "Novice")
        case .beginner: return L10n.t("初级", "Beginner")
        case .intermediate: return L10n.t("中级", "Intermediate")
        case .advanced: return L10n.t("高级", "Advanced")
        case .elite: return L10n.t("精英", "Elite")
        }
    }

    var color: Color {
        switch self {
        case .novice: return .gray
        case .beginner: return .blue
        case .intermediate: return .green
        case .advanced: return .purple
        case .elite: return .yellow
        }
    }

    var systemImage: String {
        switch self {
        case .novice: return "leaf"
        case .beginner: return "figure.walk"
        case .intermediate: return "figure.strengthtraining.traditional"
        case .advanced: return "bolt.fill"
        case .elite: return "crown.fill"
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
    ]

    /// Bodyweight outside this range is clamped (per DOTS convention).
    private static let bodyweightRange: ClosedRange<Double> = 40...210

    static func score(liftedKg: Double, bodyweightKg: Double, sex: Sex) -> Double {
        guard liftedKg > 0 else { return 0 }
        let bw = min(max(bodyweightKg, bodyweightRange.lowerBound), bodyweightRange.upperBound)
        let c = coefficients[sex]!
        let denom = c[0] + c[1] * bw + c[2] * pow(bw, 2) + c[3] * pow(bw, 3) + c[4] * pow(bw, 4)
        guard denom > 0 else { return 0 }
        return liftedKg * 500 / denom
    }
}

/// Maps DOTS scores to 新手→精英 tiers, per lift and sex.
enum StrengthStandards {

    // ======================================================================
    // Tier boundaries as DOTS scores: [初级 starts, 中级 starts, 高级 starts,
    // 精英 starts], per lift and sex.
    //
    // Derived from strengthlevel.com-style percentile standards converted to
    // DOTS at a reference bodyweight (75 kg male / 60 kg female). Anchors
    // (kg lifted at the reference bw → tier):
    //
    //   male:   squat 93/131/176/219   bench 60/90/130/170
    //           dead   107/152/200/245 ohp   40/57/77/97
    //   female: squat 51/78/108/137    bench 27/45/68/95
    //           dead   62/94/128/161   ohp   22/33/47/61
    //
    // Sanity check: a 130 kg bench at 70 kg bw (DOTS ≈ 98) is 高级 for men.
    // Still approximations — refine against real meet data (openpowerlifting,
    // CPA/IPL China) before launch if tighter accuracy matters.
    // ======================================================================
    private static let thresholds: [CoreLift: [Sex: [Double]]] = [
        .squat:    [.male: [66, 93, 126, 157], .female: [56, 86, 119, 151]],
        .bench:    [.male: [43, 64, 93, 121],  .female: [29, 49, 75, 105]],
        .deadlift: [.male: [76, 109, 143, 175], .female: [68, 104, 141, 178]],
        .ohp:      [.male: [28, 40, 55, 69],   .female: [24, 36, 52, 67]],
    ]

    static func tier(for dots: Double, lift: CoreLift, sex: Sex) -> StrengthTier {
        let bounds = thresholds[lift]![sex]!
        var tier = StrengthTier.novice
        for (index, boundary) in bounds.enumerated() where dots >= boundary {
            tier = StrengthTier(rawValue: index + 1) ?? .elite
        }
        return tier
    }

    /// Progress (0...1) from the current tier toward the next, plus the DOTS
    /// score needed to reach it (nil if already elite).
    static func progressToNextTier(dots: Double, lift: CoreLift, sex: Sex)
        -> (tier: StrengthTier, progress: Double, nextBoundary: Double?)
    {
        let bounds = thresholds[lift]![sex]!
        let tier = tier(for: dots, lift: lift, sex: sex)
        guard tier != .elite else { return (tier, 1, nil) }

        let lower = tier == .novice ? 0 : bounds[tier.rawValue - 1]
        let upper = bounds[tier.rawValue]
        let progress = upper > lower ? min(max((dots - lower) / (upper - lower), 0), 1) : 0
        return (tier, progress, upper)
    }
}
