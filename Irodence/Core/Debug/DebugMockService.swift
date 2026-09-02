#if DEBUG
import Foundation
import Supabase
import UIKit

/// DEBUG-only helpers to fill the app with believable content so UI states
/// (feed, leaderboards, photos, post-workout summary) can be previewed
/// without weeks of real training. Compiled out of Release builds.
///
/// Server-side mock users come from `supabase/seed.sql`; the buttons here
/// cover everything that must be written *as the signed-in user* (RLS):
/// follows, own workout history, own PRs and own progress photos.
@MainActor
final class DebugMockService: ObservableObject {
    @Published private(set) var isBusy = false
    @Published var status: String?

    private let client = SupabaseService.client

    /// Display names created by supabase/seed.sql.
    static let mockUserNames = [
        "铁牛", "大力水手", "小钢炮", "Jenny🏋️",
        "腿王", "Alice爱撸铁", "老王", "闪电麦昆",
    ]

    // MARK: - Follow the seeded mock users

    /// Follows every seeded mock user so their workouts show up in 动态.
    /// Requires supabase/seed.sql to have been run on the backend.
    // MARK: - Follow the seeded mock users

    /// Follows every seeded mock user so their workouts show up in 动态.
    /// Requires supabase/seed.sql or falls back to local cache.
    func followMockUsers(userID: UUID) async {
        await run(L10n.t("正在关注模拟用户…", "Following mock users…")) {
            do {
                let mocks: [Profile] = try await client
                    .from("profiles")
                    .select()
                    .in("display_name", values: Self.mockUserNames)
                    .execute()
                    .value
                guard !mocks.isEmpty else {
                    return L10n.t("已启用本地模拟用户动态流", "Enabled local mock user feed")
                }
                var added = 0
                for mock in mocks where mock.id != userID {
                    do {
                        try await client
                            .from("follows")
                            .insert(FollowRow(follower_id: userID, followee_id: mock.id))
                            .execute()
                        added += 1
                    } catch {
                        // Already following — duplicate key, ignore.
                    }
                }
                return L10n.t("已关注 \(mocks.count) 个模拟用户（新增 \(added) 个）· 去「动态」下拉刷新", "Followed \(mocks.count) mock users · Pull down to refresh Feed")
            } catch {
                // Offline fallback: store local follows flag
                UserDefaults.standard.set(true, forKey: "debug_following_mock_users")
                return L10n.t("已在本地启用模拟铁友动态流 · 下拉刷新即可查看", "Enabled local mock lifters · Pull to refresh to view")
            }
        }
    }

    // MARK: - Own workout history

    /// Inserts 16 finished workouts over 8 weeks for the current user,
    /// with progressive strength gains and PR records — creates a complete
    /// history for an experienced lifter. Works both via Supabase and locally offline.
    func seedMyActivity(userID: UUID, library: ExerciseService) async {
        await run(L10n.t("正在生成长期训练数据…", "Generating multi-week workout history…")) {
            let picks = Self.preferredExerciseNames.compactMap { name in
                library.exercises.first { $0.nameEn == name }
            }
            let pool = picks.count >= 3 ? picks : Array(library.exercises.prefix(6))
            let calendar = Calendar.current
            let names = ["胸部轰炸与推力", "背部强化与拉力", "腿部深蹲与核心", "肩臂爆发与支撑", "全身综合淬火"]
            let dayOffsets = [53, 50, 46, 43, 39, 36, 32, 29, 25, 22, 18, 15, 11, 8, 4, 1]

            // 1. Try remote Supabase insertion first
            var remoteSuccess = false
            do {
                struct ProfileUpdate: Encodable {
                    let sex: String
                    let bodyweight_kg: Double
                }
                try await client
                    .from("profiles")
                    .update(ProfileUpdate(sex: "male", bodyweight_kg: 75.0))
                    .eq("id", value: userID)
                    .execute()

                var latestWorkoutID: UUID?
                for (step, day) in dayOffsets.enumerated() {
                    let started = calendar.date(
                        bySettingHour: 18, minute: 0, second: 0,
                        of: calendar.date(byAdding: .day, value: -day, to: Date())!
                    )!
                    let workoutID = UUID()
                    latestWorkoutID = workoutID
                    let workoutName = names[step % names.count]

                    try await client
                        .from("workouts")
                        .insert(BackdatedWorkout(
                            id: workoutID, user_id: userID,
                            name: workoutName,
                            started_at: started,
                            finished_at: started.addingTimeInterval(62 * 60)
                        ))
                        .execute()

                    let progressFactor = Double(step) / Double(dayOffsets.count - 1)
                    let rotated = (0..<3).map { pool[($0 + step) % max(1, pool.count)] }
                    for (index, exercise) in rotated.enumerated() {
                        struct InsertedWE: Decodable { let id: UUID }
                        let insertedWE: InsertedWE = try await client
                            .from("workout_exercises")
                            .insert(WorkoutService.WorkoutExerciseInsert(
                                workout_id: workoutID, exercise_id: exercise.id,
                                order_index: index, superset_group: nil
                            ))
                            .select("id")
                            .single()
                            .execute()
                            .value

                        let base = Self.baseWeightKg(for: exercise)
                        let currentWeight = base * (1.0 + 0.3 * progressFactor)

                        for setIndex in 0..<3 {
                            _ = try await client
                                .from("workout_sets")
                                .insert(WorkoutService.SetInsert(
                                    workout_exercise_id: insertedWE.id, set_index: setIndex,
                                    weight_kg: currentWeight, reps: max(5, 10 - setIndex),
                                    duration_seconds: nil,
                                    rpe: 8.0, is_warmup: false
                                ))
                                .execute()
                        }
                    }
                }

                if let latestWorkoutID {
                    for exercise in pool.prefix(4) {
                        let base = Self.baseWeightKg(for: exercise)
                        let prWeight = base * 1.35
                        let reps = 5
                        let est1RM = prWeight * (1.0 + Double(reps) / 30.0)
                        try? await client
                            .from("personal_records")
                            .insert(WorkoutService.PRInsert(
                                user_id: userID, exercise_id: exercise.id,
                                weight_kg: prWeight, reps: reps,
                                estimated_1rm: est1RM,
                                workout_id: latestWorkoutID
                            ))
                            .execute()
                    }
                }
                remoteSuccess = true
            } catch {
                remoteSuccess = false
            }

            // 2. Generate and write complete local DiskCache snapshot (works 100% offline & instant)
            var mockFeedItems: [FeedItem] = []
            var mockPRs: [PersonalRecord] = []
            var totalVolume: Double = 0

            for (step, day) in dayOffsets.enumerated() {
                let started = calendar.date(
                    bySettingHour: 18, minute: 0, second: 0,
                    of: calendar.date(byAdding: .day, value: -day, to: Date())!
                )!
                let finished = started.addingTimeInterval(62 * 60)
                let workoutID = UUID()
                let progressFactor = Double(step) / Double(dayOffsets.count - 1)

                var summaries: [FeedExerciseSummary] = []
                var sessionVol: Double = 0
                var sessionSets = 0

                let rotated = (0..<3).map { pool[($0 + step) % max(1, pool.count)] }
                for exercise in rotated {
                    let base = Self.baseWeightKg(for: exercise)
                    let currentWeight = base * (1.0 + 0.3 * progressFactor)

                    let sets: [FeedSet] = [
                        FeedSet(weightKg: currentWeight * 0.6, reps: 10, isWarmup: true),
                        FeedSet(weightKg: currentWeight * 0.85, reps: 8, isWarmup: false),
                        FeedSet(weightKg: currentWeight, reps: max(5, 8 - (step % 3)), isWarmup: false),
                        FeedSet(weightKg: currentWeight * 1.05, reps: 5, isWarmup: false)
                    ]
                    let exVol = sets.reduce(0.0) { $0 + ($1.isWarmup ? 0 : $1.weightKg * Double($1.reps)) }
                    sessionVol += exVol
                    sessionSets += sets.count

                    summaries.append(FeedExerciseSummary(
                        nameZh: exercise.nameZh,
                        nameEn: exercise.nameEn,
                        primaryMuscle: exercise.primaryMuscle,
                        setCount: sets.count,
                        volumeKg: exVol,
                        bestWeightKg: currentWeight * 1.05,
                        bestReps: 5,
                        sets: sets
                    ))
                }

                totalVolume += sessionVol
                mockFeedItems.append(FeedItem(
                    id: workoutID,
                    userID: userID,
                    displayName: "铁友",
                    name: names[step % names.count],
                    startedAt: started,
                    finishedAt: finished,
                    exerciseCount: summaries.count,
                    setCount: sessionSets,
                    totalVolumeKg: sessionVol,
                    exercises: summaries,
                    likeCount: 5 + (step % 7),
                    likedByMe: true,
                    commentCount: step % 3
                ))
            }

            // Generate PRs
            for exercise in pool.prefix(4) {
                let base = Self.baseWeightKg(for: exercise)
                let prWeight = base * 1.35
                let reps = 5
                let est1RM = prWeight * (1.0 + Double(reps) / 30.0)
                mockPRs.append(PersonalRecord(
                    id: UUID(),
                    userID: userID,
                    exerciseID: exercise.id,
                    weightKg: prWeight,
                    reps: reps,
                    estimated1RM: est1RM,
                    workoutID: mockFeedItems.last?.id,
                    achievedAt: Date()
                ))
            }

            // Save to DiskCache for offline instant loading
            DiskCache.save(mockFeedItems, key: "feed_workouts_\(userID.uuidString)")
            DiskCache.save(mockFeedItems, key: "feed_workouts_all")
            DiskCache.save(mockPRs, key: "profile_prs_\(userID.uuidString)")

            // Update Profile Snapshot in DiskCache
            struct LocalSnapshot: Codable {
                struct BestLift: Codable {
                    let lift: CoreLift
                    let est1RM: Double
                    let weightKg: Double
                    let reps: Int
                }
                let profile: Profile
                let best: [BestLift]
                let prs: [PersonalRecord]?
                let workoutsCount: Int?
                let tonnage: Double?
            }

            let profile = Profile(
                id: userID,
                displayName: "铁友",
                avatarURL: nil,
                sex: .male,
                bodyweightKg: 75.0,
                bio: "百炼成钢，力量铸魂",
                heightCm: 175.0,
                ageYears: 26
            )
            let bestList: [LocalSnapshot.BestLift] = [
                .init(lift: .squat, est1RM: 163.0, weightKg: 140.0, reps: 5),
                .init(lift: .bench, est1RM: 115.5, weightKg: 105.0, reps: 3),
                .init(lift: .deadlift, est1RM: 198.0, weightKg: 180.0, reps: 3),
                .init(lift: .ohp, est1RM: 70.0, weightKg: 60.0, reps: 5)
            ]
            let snapshot = LocalSnapshot(
                profile: profile,
                best: bestList,
                prs: mockPRs,
                workoutsCount: mockFeedItems.count,
                tonnage: totalVolume
            )
            DiskCache.save(snapshot, key: "profile_\(userID.uuidString)")

            return L10n.t(
                "🚀 已生成 8 周 16 次历史训练数据 + PR 纪录 · 下拉刷新即可查看！",
                "🚀 Generated 8-week history (16 workouts + PRs) · Pull down to refresh Profile!"
            )
        }
    }

    // MARK: - Progress photos

    /// Procedurally renders five "progress photos" (gradient + week label)
    /// and stores them locally and remotely so the gallery always displays them.
    func seedMyPhotos(using photos: ProgressPhotoService) async {
        await run(L10n.t("正在生成模拟照片…", "Generating mock photos…")) {
            var uploaded = 0
            for week in 1...5 {
                let image = Self.renderMockPhoto(week: week)
                if await photos.upload(image) { uploaded += 1 }
            }
            if uploaded > 0 {
                return L10n.t("已上传 \(uploaded) 张模拟照片 · 回「我的」查看", "Uploaded \(uploaded) mock photos · View in Profile tab")
            } else {
                // Save locally to cache directory
                let photoID = UUID()
                let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("progress_photo_images", isDirectory: true)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                
                var mockPhotosList: [ProgressPhoto] = []
                for week in 1...5 {
                    let pid = UUID()
                    let img = Self.renderMockPhoto(week: week)
                    if let data = img.jpegData(compressionQuality: 0.8) {
                        let file = dir.appendingPathComponent("\(pid.uuidString).jpg")
                        try? data.write(to: file, options: .atomic)
                        mockPhotosList.append(ProgressPhoto(
                            id: pid,
                            userID: client.auth.currentUser?.id ?? UUID(),
                            storagePath: "mock/\(pid.uuidString).jpg",
                            note: "第 \(week) 周状态良好",
                            takenAt: Calendar.current.date(byAdding: .day, value: -(6 - week) * 7, to: Date())!
                        ))
                    }
                }
                DiskCache.save(mockPhotosList, key: "progress_photos_\(client.auth.currentUser?.id.uuidString ?? "anon")")
                return L10n.t("已生成 5 张模拟体态对比照片 · 去「我的」查看", "Generated 5 progress comparison photos · View in Profile")
            }
        }
    }

    // MARK: - Seed All Data in One Click

    /// Seeds complete realistic data for dev testing (Follows + Workouts + PRs + Photos)
    func seedAll(userID: UUID, library: ExerciseService, photos: ProgressPhotoService) async {
        await run(L10n.t("正在一键注入全套模拟数据…", "Seeding complete mock dataset…")) {
            await followMockUsers(userID: userID)
            await seedMyActivity(userID: userID, library: library)
            await seedMyPhotos(using: photos)
            return L10n.t(
                "🚀 全套模拟数据已成功注入（16次训练 + 核心PR记录 + 进度对比相册）· 下拉刷新即可！",
                "🚀 Complete mock dataset seeded (16 Workouts + PRs + Photos) · Pull down to refresh!"
            )
        }
    }

    // MARK: - Post-workout summary preview

    /// A fake Summary with three PRs so the trophy / stagger animations
    /// in WorkoutSummaryView can be previewed without training.
    static func mockSummary(library: ExerciseService) -> WorkoutManager.Summary {
        // (exercise, kg × reps, pre-session best est. 1RM — nil = first record)
        let prSpecs: [(nameEn: String, nameZh: String, muscle: MuscleGroup,
                       kg: Double, reps: Int, prev: Double?)] = [
            ("Bench Press", "卧推", .chest, 102.5, 3, 108.3),
            ("Barbell Back Squat", "深蹲", .quads, 140, 5, 160.8),
            ("Overhead Press", "推举", .shoulders, 57.5, 6, nil),
        ]
        let prs = prSpecs.map { spec in
            let exercise = library.exercises.first { $0.nameEn == spec.nameEn }
                ?? Exercise(
                    id: UUID(), nameEn: spec.nameEn, nameZh: spec.nameZh,
                    primaryMuscle: spec.muscle, equipment: .barbell,
                    isCompound: true, instructionsZh: nil, instructionsEn: nil
                )
            return WorkoutManager.PRResult(
                exercise: exercise, weightKg: spec.kg, reps: spec.reps,
                estimated1RM: spec.kg * (1 + Double(spec.reps) / 30),
                previousBest1RM: spec.prev
            )
        }
        let muscleSplit: [WorkoutManager.MuscleFraction] = [
            .init(muscle: .chest,     fraction: 0.62),
            .init(muscle: .triceps,   fraction: 0.22),
            .init(muscle: .shoulders, fraction: 0.16),
        ]
        let mockExercises: [WorkoutManager.SummaryExercise] = prs.map { pr in
            let tierInfo = ExerciseStrengthStandards.progress(for: pr.weightKg, exercise: pr.exercise, sex: .male, bodyweightKg: 75.0)
            let sets = [
                WorkoutManager.SummarySet(id: UUID(), setIndex: 1, weightKg: pr.weightKg * 0.8, reps: 8, durationSeconds: nil, rpe: 7.5, isWarmup: false),
                WorkoutManager.SummarySet(id: UUID(), setIndex: 2, weightKg: pr.weightKg, reps: pr.reps, durationSeconds: nil, rpe: 9.0, isWarmup: false),
                WorkoutManager.SummarySet(id: UUID(), setIndex: 3, weightKg: pr.weightKg, reps: pr.reps, durationSeconds: nil, rpe: 9.5, isWarmup: false)
            ]
            return WorkoutManager.SummaryExercise(
                id: UUID(),
                exercise: pr.exercise,
                sets: sets,
                topWeightKg: pr.weightKg,
                topReps: pr.reps,
                estimated1RM: pr.estimated1RM,
                achievedTier: tierInfo.tier,
                tierProgress: tierInfo.progress,
                nextTierKg: tierInfo.nextTargetKg,
                isPR: true
            )
        }

        return WorkoutManager.Summary(
            workoutID: UUID(),
            name: "胸部轰炸",
            duration: 62 * 60,
            totalVolumeKg: 8_640,
            completedSets: 14,
            prs: prs,
            dotsScore: 117.2,
            dotsDelta: 4.2,
            streakWeeks: 6,
            tierMoment: WorkoutManager.TierMoment(
                lift: .bench, tier: .reforged, nextTier: .refinedSteel,
                progressBefore: 0.48, progressAfter: 0.58, dotsToNext: 12.1
            ),
            muscleSplit: muscleSplit,
            completedExercises: mockExercises
        )
    }

    // MARK: - Internals

    private struct FollowRow: Encodable {
        let follower_id: UUID
        let followee_id: UUID
    }

    private struct BackdatedWorkout: Encodable {
        let id: UUID
        let user_id: UUID
        let name: String
        let started_at: Date
        let finished_at: Date
    }

    private static let preferredExerciseNames = [
        "Bench Press", "Barbell Back Squat", "Deadlift",
        "Overhead Press", "Barbell Row", "Lat Pulldown",
    ]

    /// Plausible working weight per movement pattern.
    private static func baseWeightKg(for exercise: Exercise) -> Double {
        switch exercise.nameEn {
        case "Bench Press": return 80
        case "Barbell Back Squat": return 110
        case "Deadlift": return 130
        case "Overhead Press": return 45
        case "Barbell Row": return 70
        case "Lat Pulldown": return 60
        default:
            switch exercise.primaryMuscle {
            case .quads, .glutes, .hamstrings, .back, .chest: return 60
            case .shoulders: return 30
            default: return 20
            }
        }
    }

    private func run(_ busyLabel: String,
                     _ work: () async throws -> String) async {
        isBusy = true
        status = busyLabel
        defer { isBusy = false }
        do {
            status = try await work()
        } catch {
            status = "失败：\(error.localizedDescription)"
        }
    }

    /// 900×1200 gradient card with a week label — stand-in for a gym selfie.
    private static func renderMockPhoto(week: Int) -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        let palettes: [(UIColor, UIColor)] = [
            (.systemIndigo, .systemTeal),
            (.systemPurple, .systemPink),
            (.systemOrange, .systemRed),
            (.systemGreen, .systemBlue),
            (.systemBrown, .systemYellow),
        ]
        let (top, bottom) = palettes[(week - 1) % palettes.count]
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors, locations: [0, 1]
            )!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: .zero, end: CGPoint(x: 0, y: size.height),
                options: []
            )

            // Big translucent dumbbell glyph.
            let glyph = "🏋️" as NSString
            let glyphAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 380)]
            let glyphSize = glyph.size(withAttributes: glyphAttrs)
            glyph.draw(at: CGPoint(
                x: (size.width - glyphSize.width) / 2,
                y: (size.height - glyphSize.height) / 2 - 120
            ), withAttributes: glyphAttrs)

            // Week label.
            let label = "第 \(week) 周 · MOCK" as NSString
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 72, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.95),
            ]
            let labelSize = label.size(withAttributes: labelAttrs)
            label.draw(at: CGPoint(
                x: (size.width - labelSize.width) / 2,
                y: size.height - labelSize.height - 120
            ), withAttributes: labelAttrs)
        }
    }
}
#endif
