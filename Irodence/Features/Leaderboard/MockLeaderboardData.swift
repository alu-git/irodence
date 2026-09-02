import Foundation

/// Unified target for leaderboard chips (Core lifts, SBD Total, or custom Exercise).
enum LeaderboardTarget: Hashable, Identifiable {
    case core(CoreLift)
    case total
    case custom(Exercise)

    var id: String {
        switch self {
        case .core(let lift): return "core_\(lift.rawValue)"
        case .total: return "total"
        case .custom(let ex): return "custom_\(ex.id.uuidString)"
        }
    }

    var displayName: String {
        switch self {
        case .core(let lift): return lift.displayName
        case .total: return L10n.t("总和", "Total")
        case .custom(let ex): return ex.displayName
        }
    }

    var isCore: Bool {
        switch self {
        case .core, .total: return true
        case .custom: return false
        }
    }
}

/// Unified model for a leaderboard row, shared by live and mock data.
struct LeaderboardEntryItem: Identifiable, Hashable, Codable {
    let id: UUID
    let userID: UUID
    let displayName: String
    let avatarURL: String?
    let sex: Sex
    let bodyweightKg: Double
    let targetID: String
    let weightKg: Double
    let estimated1RM: Double
    let reps: Int
    /// DOTS only computed and present for core lifts (深蹲, 卧推, 硬拉, 总和).
    /// Strictly nil for non-core exercises.
    let dotsScore: Double?
    let tier: StrengthTier?
    let isCertified: Bool
    let crewID: UUID?

    init(
        id: UUID = UUID(),
        userID: UUID,
        displayName: String,
        avatarURL: String? = nil,
        sex: Sex,
        bodyweightKg: Double,
        targetID: String,
        weightKg: Double,
        estimated1RM: Double? = nil,
        reps: Int = 1,
        dotsScore: Double? = nil,
        tier: StrengthTier? = nil,
        isCertified: Bool = true,
        crewID: UUID? = nil
    ) {
        self.id = id
        self.userID = userID
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.sex = sex
        self.bodyweightKg = bodyweightKg
        self.targetID = targetID
        self.weightKg = weightKg
        self.estimated1RM = estimated1RM ?? weightKg
        self.reps = reps
        self.dotsScore = dotsScore
        self.tier = tier
        self.isCertified = isCertified
        self.crewID = crewID
    }

    /// 相对力量 = 1RM / 体重 (e.g. "1.4×体重" or "1.4× BW")
    var relativeStrengthText: String {
        guard bodyweightKg > 0 else { return "—" }
        let ratio = estimated1RM / bodyweightKg
        return String(format: L10n.t("%.1f×体重", "%.1f× BW"), ratio)
    }
}

/// Standard weight class helper
enum WeightClassHelper {
    static func weightClass(for bodyweightKg: Double?, sex: Sex?) -> Int {
        guard let bw = bodyweightKg else { return 74 }
        let isFemale = sex == .female

        if isFemale {
            let classes = [47, 52, 57, 63, 69, 76, 84]
            for c in classes where bw <= Double(c) {
                return c
            }
            return 84
        } else {
            let classes = [59, 66, 74, 83, 93, 105, 120]
            for c in classes where bw <= Double(c) {
                return c
            }
            return 120
        }
    }
}

#if DEBUG
/// Mock leaderboard dataset with 12 lifters at plausible strong-amateur level.
/// Gated behind #if DEBUG.
enum MockLeaderboardData {
    static let mockCrewID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    static let otherCrewID = UUID(uuidString: "66666666-7777-8888-9999-000000000000")!

    // Non-core mock exercise IDs
    static let pullupExerciseID = UUID(uuidString: "22222222-0000-0000-0000-000000000001")!
    static let ohpExerciseID = UUID(uuidString: "22222222-0000-0000-0000-000000000002")!
    static let sparseExerciseID = UUID(uuidString: "22222222-0000-0000-0000-000000000003")!

    static let pullupExercise = Exercise(
        id: pullupExerciseID,
        nameEn: "Weighted Pull-Up",
        nameZh: "引体向上",
        primaryMuscle: .back,
        equipment: .bodyweight,
        isCompound: true
    )

    static let ohpExercise = Exercise(
        id: ohpExerciseID,
        nameEn: "Standing Overhead Press",
        nameZh: "站姿推举",
        primaryMuscle: .shoulders,
        equipment: .barbell,
        isCompound: true
    )

    static let sparseExercise = Exercise(
        id: sparseExerciseID,
        nameEn: "Barbell Row",
        nameZh: "杠铃划船",
        primaryMuscle: .back,
        equipment: .barbell,
        isCompound: true
    )

    static let users: [LeaderboardEntryItem] = generateMockEntries()

    private static func generateMockEntries() -> [LeaderboardEntryItem] {
        struct LifterRaw {
            let name: String
            let sex: Sex
            let bw: Double
            let squat: Double
            let bench: Double
            let deadlift: Double
            let pullupAdded: Double?
            let ohpWeight: Double?
            let isCurrentCrew: Bool
            let isCertified: Bool
            let avatarURL: String?
        }

        // 12 realistic strong-amateur lifters (a healthy mix of video certified and self-reported lifters)
        let rawLifters: [LifterRaw] = [
            // 1. 魏铁峰 - 百炼 男 83kg (Video Certified)
            LifterRaw(name: L10n.t("魏铁峰", "Tiefeng Wei"), sex: .male, bw: 83.0, squat: 180.0, bench: 125.0, deadlift: 220.0, pullupAdded: 35.0, ohpWeight: 75.0, isCurrentCrew: true, isCertified: true, avatarURL: nil),
            // 2. 林岚 - 精钢/百炼 女 57kg (Video Certified)
            LifterRaw(name: L10n.t("林岚", "Lan Lin"), sex: .female, bw: 57.0, squat: 105.0, bench: 62.5, deadlift: 130.0, pullupAdded: 15.0, ohpWeight: 40.0, isCurrentCrew: true, isCertified: true, avatarURL: nil),
            // 3. 赵一鸣 - 精钢 男 74kg (Self-Reported)
            LifterRaw(name: L10n.t("赵一鸣", "Yiming Zhao"), sex: .male, bw: 74.0, squat: 160.0, bench: 110.0, deadlift: 190.0, pullupAdded: 27.5, ohpWeight: 65.0, isCurrentCrew: false, isCertified: false, avatarURL: nil),
            // 4. 陈静 - 重锻/精钢 女 52kg (Video Certified)
            LifterRaw(name: L10n.t("陈静", "Jing Chen"), sex: .female, bw: 52.0, squat: 85.0, bench: 50.0, deadlift: 110.0, pullupAdded: 12.5, ohpWeight: 35.0, isCurrentCrew: true, isCertified: true, avatarURL: nil),
            // 5. 许晓琳 - 重锻/精钢 女 63kg (Self-Reported)
            LifterRaw(name: L10n.t("许晓琳", "Xiaolin Xu"), sex: .female, bw: 63.0, squat: 100.0, bench: 57.5, deadlift: 125.0, pullupAdded: 15.0, ohpWeight: 42.5, isCurrentCrew: true, isCertified: false, avatarURL: nil),
            // 6. 郭子昂 - 精钢 男 93kg (Video Certified)
            LifterRaw(name: L10n.t("郭子昂", "Ziang Guo"), sex: .male, bw: 93.0, squat: 175.0, bench: 120.0, deadlift: 210.0, pullupAdded: 25.0, ohpWeight: 70.0, isCurrentCrew: false, isCertified: true, avatarURL: nil),
            // 7. 孙浩然 - 重锻 男 74kg (Self-Reported)
            LifterRaw(name: L10n.t("孙浩然", "Haoran Sun"), sex: .male, bw: 74.0, squat: 140.0, bench: 95.0, deadlift: 165.0, pullupAdded: 20.0, ohpWeight: 55.0, isCurrentCrew: true, isCertified: false, avatarURL: nil),
            // 8. 周宇 - 重锻 男 83kg (Video Certified)
            LifterRaw(name: L10n.t("周宇", "Yu Zhou"), sex: .male, bw: 83.0, squat: 145.0, bench: 100.0, deadlift: 175.0, pullupAdded: 20.0, ohpWeight: 60.0, isCurrentCrew: false, isCertified: true, avatarURL: nil),
            // 9. 陆天行 - 熟铁 男 66kg (Self-Reported)
            LifterRaw(name: L10n.t("陆天行", "Tianxing Lu"), sex: .male, bw: 66.0, squat: 110.0, bench: 70.0, deadlift: 130.0, pullupAdded: nil, ohpWeight: nil, isCurrentCrew: true, isCertified: false, avatarURL: nil),
            // 10. 马建国 - 熟铁 男 83kg (Self-Reported)
            LifterRaw(name: L10n.t("马建国", "Jianguo Ma"), sex: .male, bw: 83.0, squat: 120.0, bench: 80.0, deadlift: 140.0, pullupAdded: nil, ohpWeight: nil, isCurrentCrew: false, isCertified: false, avatarURL: nil),
            // 11. 张小北 - 生铁 男 74kg (Self-Reported)
            LifterRaw(name: L10n.t("张小北", "Xiaobei Zhang"), sex: .male, bw: 74.0, squat: 80.0, bench: 55.0, deadlift: 100.0, pullupAdded: nil, ohpWeight: nil, isCurrentCrew: true, isCertified: false, avatarURL: nil),
            // 12. 刘铭 - 生铁 男 66kg (Self-Reported)
            LifterRaw(name: L10n.t("刘铭", "Ming Liu"), sex: .male, bw: 66.0, squat: 70.0, bench: 45.0, deadlift: 85.0, pullupAdded: nil, ohpWeight: nil, isCurrentCrew: false, isCertified: false, avatarURL: nil)
        ]

        var items: [LeaderboardEntryItem] = []

        for raw in rawLifters {
            let uid = UUID()
            let crewID = raw.isCurrentCrew ? mockCrewID : otherCrewID

            // 1. Squat (Core Lift -> with DOTS score and tier)
            let squatDots = DOTSCalculator.score(liftedKg: raw.squat, bodyweightKg: raw.bw, sex: raw.sex)
            let squatTier = StrengthStandards.tier(for: squatDots, lift: .squat, sex: raw.sex)
            items.append(LeaderboardEntryItem(
                userID: uid,
                displayName: raw.name,
                avatarURL: raw.avatarURL,
                sex: raw.sex,
                bodyweightKg: raw.bw,
                targetID: LeaderboardTarget.core(.squat).id,
                weightKg: raw.squat,
                estimated1RM: raw.squat,
                dotsScore: squatDots,
                tier: squatTier,
                isCertified: raw.isCertified,
                crewID: crewID
            ))

            // 2. Bench (Core Lift -> with DOTS score and tier)
            let benchDots = DOTSCalculator.score(liftedKg: raw.bench, bodyweightKg: raw.bw, sex: raw.sex)
            let benchTier = StrengthStandards.tier(for: benchDots, lift: .bench, sex: raw.sex)
            items.append(LeaderboardEntryItem(
                userID: uid,
                displayName: raw.name,
                avatarURL: raw.avatarURL,
                sex: raw.sex,
                bodyweightKg: raw.bw,
                targetID: LeaderboardTarget.core(.bench).id,
                weightKg: raw.bench,
                estimated1RM: raw.bench,
                dotsScore: benchDots,
                tier: benchTier,
                isCertified: raw.isCertified,
                crewID: crewID
            ))

            // 3. Deadlift (Core Lift -> with DOTS score and tier)
            let dlDots = DOTSCalculator.score(liftedKg: raw.deadlift, bodyweightKg: raw.bw, sex: raw.sex)
            let dlTier = StrengthStandards.tier(for: dlDots, lift: .deadlift, sex: raw.sex)
            items.append(LeaderboardEntryItem(
                userID: uid,
                displayName: raw.name,
                avatarURL: raw.avatarURL,
                sex: raw.sex,
                bodyweightKg: raw.bw,
                targetID: LeaderboardTarget.core(.deadlift).id,
                weightKg: raw.deadlift,
                estimated1RM: raw.deadlift,
                dotsScore: dlDots,
                tier: dlTier,
                isCertified: raw.isCertified,
                crewID: crewID
            ))

            // 4. Total (Core Lift -> with DOTS score and tier)
            let totalKg = raw.squat + raw.bench + raw.deadlift
            let totalDots = DOTSCalculator.score(liftedKg: totalKg, bodyweightKg: raw.bw, sex: raw.sex)
            let totalTier = StrengthStandards.tier(for: totalDots / 3.0, lift: .squat, sex: raw.sex)
            items.append(LeaderboardEntryItem(
                userID: uid,
                displayName: raw.name,
                avatarURL: raw.avatarURL,
                sex: raw.sex,
                bodyweightKg: raw.bw,
                targetID: LeaderboardTarget.total.id,
                weightKg: totalKg,
                estimated1RM: totalKg,
                dotsScore: totalDots,
                tier: totalTier,
                isCertified: raw.isCertified,
                crewID: crewID
            ))

            // 5. Non-core 1: 引体向上 (Weighted Pull-Up) -> 1RM (Total load = bodyweight + added weight), NO DOTS score
            if let added = raw.pullupAdded {
                let est1RM = raw.bw + added
                items.append(LeaderboardEntryItem(
                    userID: uid,
                    displayName: raw.name,
                    avatarURL: raw.avatarURL,
                    sex: raw.sex,
                    bodyweightKg: raw.bw,
                    targetID: LeaderboardTarget.custom(pullupExercise).id,
                    weightKg: added,
                    estimated1RM: est1RM,
                    dotsScore: nil, // STRICTLY nil for non-core
                    tier: nil,
                    isCertified: true,
                    crewID: crewID
                ))
            }

            // 6. Non-core 2: 站姿推举 (Standing Overhead Press) -> 1RM, NO DOTS score
            if let ohp = raw.ohpWeight {
                items.append(LeaderboardEntryItem(
                    userID: uid,
                    displayName: raw.name,
                    avatarURL: raw.avatarURL,
                    sex: raw.sex,
                    bodyweightKg: raw.bw,
                    targetID: LeaderboardTarget.custom(ohpExercise).id,
                    weightKg: ohp,
                    estimated1RM: ohp,
                    dotsScore: nil, // STRICTLY nil for non-core
                    tier: nil,
                    isCertified: true,
                    crewID: crewID
                ))
            }
        }

        // 7. Non-core 3: 杠铃划船 (Sparse board: ONLY 1 certified entry < 3 threshold)
        items.append(LeaderboardEntryItem(
            userID: UUID(),
            displayName: "魏铁峰",
            avatarURL: nil,
            sex: .male,
            bodyweightKg: 83.0,
            targetID: LeaderboardTarget.custom(sparseExercise).id,
            weightKg: 85.0,
            estimated1RM: 85.0,
            dotsScore: nil,
            tier: nil,
            isCertified: true,
            crewID: mockCrewID
        ))

        return items
    }
}

/// Past training history generator for user mock data
enum MockUserTrainingHistory {
    static func generateMockFeedItems(userID: UUID, displayName: String = L10n.t("铁友 (你)", "Lifter (You)")) -> [FeedItem] {
        let calendar = Calendar.current
        let now = Date()

        // 1. 深蹲与下肢力量
        let squatSets = [
            FeedSet(weightKg: 60.0, reps: 10, isWarmup: true),
            FeedSet(weightKg: 100.0, reps: 5, isWarmup: false),
            FeedSet(weightKg: 120.0, reps: 5, isWarmup: false),
            FeedSet(weightKg: 140.0, reps: 3, isWarmup: false)
        ]
        let legExtSets = [
            FeedSet(weightKg: 45.0, reps: 12, isWarmup: false),
            FeedSet(weightKg: 55.0, reps: 10, isWarmup: false),
            FeedSet(weightKg: 65.0, reps: 8, isWarmup: false)
        ]
        let rdlSets = [
            FeedSet(weightKg: 80.0, reps: 8, isWarmup: false),
            FeedSet(weightKg: 100.0, reps: 6, isWarmup: false),
            FeedSet(weightKg: 110.0, reps: 6, isWarmup: false)
        ]

        let squatExercises = [
            FeedExerciseSummary(nameZh: "杠铃后深蹲", nameEn: "Barbell Back Squat", primaryMuscle: .quads, setCount: 4, volumeKg: 2020.0, bestWeightKg: 140.0, bestReps: 3, sets: squatSets),
            FeedExerciseSummary(nameZh: "腿屈伸", nameEn: "Leg Extension", primaryMuscle: .quads, setCount: 3, volumeKg: 1610.0, bestWeightKg: 65.0, bestReps: 8, sets: legExtSets),
            FeedExerciseSummary(nameZh: "罗马尼亚硬拉", nameEn: "Romanian Deadlift", primaryMuscle: .hamstrings, setCount: 3, volumeKg: 1900.0, bestWeightKg: 110.0, bestReps: 6, sets: rdlSets)
        ]

        let w1 = FeedItem(
            id: UUID(),
            userID: userID,
            displayName: displayName,
            name: L10n.t("深蹲与下肢力量", "Squat & Lower Body Power"),
            startedAt: calendar.date(byAdding: .day, value: -1, to: now)!,
            finishedAt: calendar.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(3600),
            exerciseCount: 3,
            setCount: 10,
            totalVolumeKg: 5530.0,
            exercises: squatExercises,
            likeCount: 4,
            likedByMe: false,
            commentCount: 2
        )

        // 2. 卧推轰炸与上肢推力
        let benchSets = [
            FeedSet(weightKg: 50.0, reps: 10, isWarmup: true),
            FeedSet(weightKg: 80.0, reps: 6, isWarmup: false),
            FeedSet(weightKg: 95.0, reps: 5, isWarmup: false),
            FeedSet(weightKg: 105.0, reps: 3, isWarmup: false)
        ]
        let inclineDbSets = [
            FeedSet(weightKg: 28.0, reps: 10, isWarmup: false),
            FeedSet(weightKg: 32.0, reps: 8, isWarmup: false),
            FeedSet(weightKg: 34.0, reps: 6, isWarmup: false)
        ]
        let dipSets = [
            FeedSet(weightKg: 15.0, reps: 10, isWarmup: false),
            FeedSet(weightKg: 20.0, reps: 8, isWarmup: false),
            FeedSet(weightKg: 25.0, reps: 6, isWarmup: false)
        ]
        let benchExercises = [
            FeedExerciseSummary(nameZh: "杠铃卧推", nameEn: "Bench Press", primaryMuscle: .chest, setCount: 4, volumeKg: 1770.0, bestWeightKg: 105.0, bestReps: 3, sets: benchSets),
            FeedExerciseSummary(nameZh: "哑铃上斜卧推", nameEn: "Incline Dumbbell Press", primaryMuscle: .chest, setCount: 3, volumeKg: 740.0, bestWeightKg: 34.0, bestReps: 6, sets: inclineDbSets),
            FeedExerciseSummary(nameZh: "双杠臂屈伸", nameEn: "Dips", primaryMuscle: .triceps, setCount: 3, volumeKg: 460.0, bestWeightKg: 25.0, bestReps: 6, sets: dipSets)
        ]
        let w2 = FeedItem(
            id: UUID(),
            userID: userID,
            displayName: displayName,
            name: L10n.t("卧推轰炸与上肢推力", "Bench & Upper Body Push"),
            startedAt: calendar.date(byAdding: .day, value: -3, to: now)!,
            finishedAt: calendar.date(byAdding: .day, value: -3, to: now)!.addingTimeInterval(3300),
            exerciseCount: 3,
            setCount: 10,
            totalVolumeKg: 2970.0,
            exercises: benchExercises,
            likeCount: 6,
            likedByMe: true,
            commentCount: 1
        )

        // 3. 传统硬拉与背部强化
        let dlSets = [
            FeedSet(weightKg: 70.0, reps: 8, isWarmup: true),
            FeedSet(weightKg: 120.0, reps: 5, isWarmup: false),
            FeedSet(weightKg: 150.0, reps: 4, isWarmup: false),
            FeedSet(weightKg: 175.0, reps: 2, isWarmup: false)
        ]
        let pullupSets = [
            FeedSet(weightKg: 0.0, reps: 10, isWarmup: true),
            FeedSet(weightKg: 15.0, reps: 6, isWarmup: false),
            FeedSet(weightKg: 20.0, reps: 5, isWarmup: false),
            FeedSet(weightKg: 25.0, reps: 4, isWarmup: false)
        ]
        let deadliftExercises = [
            FeedExerciseSummary(nameZh: "传统硬拉", nameEn: "Deadlift", primaryMuscle: .back, setCount: 4, volumeKg: 2110.0, bestWeightKg: 175.0, bestReps: 2, sets: dlSets),
            FeedExerciseSummary(nameZh: "引体向上", nameEn: "Pull-Up", primaryMuscle: .back, setCount: 4, volumeKg: 290.0, bestWeightKg: 25.0, bestReps: 4, sets: pullupSets)
        ]
        let w3 = FeedItem(
            id: UUID(),
            userID: userID,
            displayName: displayName,
            name: L10n.t("硬拉拉力与背肌淬火", "Deadlift & Back Strength"),
            startedAt: calendar.date(byAdding: .day, value: -6, to: now)!,
            finishedAt: calendar.date(byAdding: .day, value: -6, to: now)!.addingTimeInterval(3900),
            exerciseCount: 2,
            setCount: 8,
            totalVolumeKg: 2400.0,
            exercises: deadliftExercises,
            likeCount: 9,
            likedByMe: true,
            commentCount: 3
        )

        return [w1, w2, w3]
    }
}
#endif
