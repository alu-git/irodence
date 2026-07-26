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
    func followMockUsers(userID: UUID) async {
        await run("正在关注模拟用户…") {
            let mocks: [Profile] = try await client
                .from("profiles")
                .select()
                .in("display_name", values: Self.mockUserNames)
                .execute()
                .value
            guard !mocks.isEmpty else {
                return "没有找到模拟用户 — 请先在 Supabase SQL 编辑器里运行 supabase/seed.sql"
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
            return "已关注 \(mocks.count) 个模拟用户（新增 \(added) 个）· 去「动态」下拉刷新"
        }
    }

    // MARK: - Own workout history

    /// Inserts five finished workouts over the past two weeks for the
    /// current user, plus PRs on the core lifts — fills 我的 / 排行榜 /
    /// 动态 with your own rows. Written directly (not via WorkoutManager)
    /// because the timestamps are backdated.
    func seedMyActivity(userID: UUID, library: ExerciseService) async {
        await run("正在生成历史训练…") {
            let picks = Self.preferredExerciseNames.compactMap { name in
                library.exercises.first { $0.nameEn == name }
            }
            let pool = picks.count >= 3 ? picks : Array(library.exercises.prefix(6))
            guard pool.count >= 3 else {
                return "动作库为空 — 请先在「动作库」下拉刷新"
            }

            let calendar = Calendar.current
            let names = ["推日", "拉日", "腿日", "上肢力量", "全身循环"]
            var firstWorkoutID: UUID?
            for (i, day) in [11, 9, 6, 4, 1].enumerated() {
                let started = calendar.date(
                    bySettingHour: 18, minute: 0, second: 0,
                    of: calendar.date(byAdding: .day, value: -day, to: Date())!
                )!
                let workoutID = UUID()
                firstWorkoutID = firstWorkoutID ?? workoutID
                try await client
                    .from("workouts")
                    .insert(BackdatedWorkout(
                        id: workoutID, user_id: userID,
                        name: names[i % names.count],
                        started_at: started,
                        finished_at: started.addingTimeInterval(58 * 60)
                    ))
                    .execute()

                // Rotate through the pool so each workout differs.
                let rotated = (0..<3).map { pool[($0 + i) % pool.count] }
                for (index, exercise) in rotated.enumerated() {
                    let weID = UUID()
                    try await client
                        .from("workout_exercises")
                        .insert(WorkoutService.WorkoutExerciseInsert(
                            workout_id: workoutID, exercise_id: exercise.id,
                            order_index: index, superset_group: nil
                        ))
                        .execute()
                    let base = Self.baseWeightKg(for: exercise)
                    for setIndex in 0..<3 {
                        _ = try await client
                            .from("workout_sets")
                            .insert(WorkoutService.SetInsert(
                                workout_exercise_id: weID, set_index: setIndex,
                                weight_kg: base, reps: 8 - setIndex,
                                duration_seconds: nil,
                                rpe: 8, is_warmup: false
                            ))
                            .execute()
                    }
                }
            }

            // PRs so 力量等级 / leaderboards light up for you too.
            for exercise in pool.prefix(4) {
                let weight = Self.baseWeightKg(for: exercise) * 1.1
                try await client
                    .from("personal_records")
                    .insert(WorkoutService.PRInsert(
                        user_id: userID, exercise_id: exercise.id,
                        weight_kg: weight, reps: 5,
                        estimated_1rm: weight * 7.0 / 6.0,
                        workout_id: firstWorkoutID!
                    ))
                    .execute()
            }
            return "已生成 5 次历史训练 + 4 条 PR · 下拉刷新「我的」"
        }
    }

    // MARK: - Progress photos

    /// Procedurally renders five "progress photos" (gradient + week label)
    /// and uploads them through the real pipeline, so storage, caching and
    /// the gallery all get exercised.
    func seedMyPhotos(using photos: ProgressPhotoService) async {
        await run("正在生成模拟照片…") {
            var uploaded = 0
            for week in 1...5 {
                let image = Self.renderMockPhoto(week: week)
                if await photos.upload(image) { uploaded += 1 }
            }
            return uploaded > 0
                ? "已上传 \(uploaded) 张模拟照片 · 切换标签页后回「我的」查看"
                : "上传失败 — \(photos.errorMessage ?? "请检查网络")"
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
        return WorkoutManager.Summary(
            name: "胸部轰炸 (预览)",
            duration: 62 * 60,
            totalVolumeKg: 8_640,
            completedSets: 14,
            prs: prs,
            dotsScore: 117.2,
            dotsDelta: 4.2,
            streakWeeks: 6,
            tierMoment: WorkoutManager.TierMoment(
                lift: .bench, tier: .intermediate, nextTier: .advanced,
                progressBefore: 0.48, progressAfter: 0.58, dotsToNext: 12.1
            )
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
