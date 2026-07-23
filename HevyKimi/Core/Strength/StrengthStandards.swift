import Foundation
import SwiftUI

enum Sex: String, Codable, CaseIterable {
    case male, female

    var displayName: String {
        switch self {
        case .male: return "男"
        case .female: return "女"
        }
    }
}

/// The four lifts that carry strength-standard rankings.
enum CoreLift: String, CaseIterable {
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
        case .squat: return "深蹲"
        case .bench: return "卧推"
        case .deadlift: return "硬拉"
        case .ohp: return "推举"
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
        case .novice: return "新手"
        case .beginner: return "初级"
        case .intermediate: return "中级"
        case .advanced: return "高级"
        case .elite: return "精英"
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
    // ⚠️ PLACEHOLDER DATA — REPLACE BEFORE LAUNCH ⚠️
    //
    // These thresholds are rough hand-tuned estimates, NOT derived from real
    // percentile data. Each array holds the 4 DOTS-score boundaries between
    // the 5 tiers: [初级 starts, 中级 starts, 高级 starts, 精英 starts].
    //
    // USER TODO(step4): supply real China/global percentile tables.
    // Recommended: derive each boundary from the percentile rank of your
    // target population (e.g. 初级 = 20th percentile, 中级 = 50th,
    // 高级 = 80th, 精英 = 95th of competitive lifters), converted to DOTS.
    // Sources to consider: openpowerlifting.org data export, 国内力量举
    // 赛事成绩 (CPA/IPL China meet results).
    // ======================================================================
    private static let thresholds: [CoreLift: [Sex: [Double]]] = [
        .squat:    [.male: [50, 110, 180, 260], .female: [40, 90, 150, 220]],
        .bench:    [.male: [40, 90, 150, 220],  .female: [25, 55, 100, 150]],
        .deadlift: [.male: [60, 130, 210, 300], .female: [50, 110, 180, 260]],
        .ohp:      [.male: [25, 55, 95, 145],   .female: [18, 40, 70, 110]],
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
