import Foundation
import SwiftUI

/// Categories for organizing training routines and programs.
enum TemplateCategory: String, CaseIterable, Identifiable {
    case all
    case ppl
    case upperLower
    case fullBody
    case powerlifting
    case specialization

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return L10n.t("全部", "All")
        case .ppl: return L10n.t("推拉腿 (PPL)", "Push Pull Legs")
        case .upperLower: return L10n.t("上下肢 (Upper/Lower)", "Upper / Lower")
        case .fullBody: return L10n.t("全身循环 (Full Body)", "Full Body")
        case .powerlifting: return L10n.t("三大项 (Powerlifting)", "Powerlifting SBD")
        case .specialization: return L10n.t("部位特化 (Specialization)", "Specialization")
        }
    }
}

/// An exercise entry within a built-in template blueprint.
struct TemplateExerciseItem: Hashable, Codable, Identifiable {
    var id: String { nameEn }
    let nameEn: String
    let nameZh: String
    let targetMuscle: MuscleGroup
    let defaultSets: Int
    let targetReps: String
    let supersetGroup: Int?

    var displayName: String {
        L10n.t(nameZh, nameEn)
    }
}

/// A ready-made workout template shipped with the app.
/// Exercises are resolved against the loaded library at start time.
struct BuiltInTemplate: Identifiable, Hashable {
    let id: String
    let zhName: String
    let enName: String
    let zhSubtitle: String
    let enSubtitle: String
    let zhDescription: String
    let enDescription: String
    let category: TemplateCategory
    let estimatedMinutes: Int
    let difficultyZh: String
    let difficultyEn: String
    let targetMuscles: [MuscleGroup]
    let systemImage: String
    let items: [TemplateExerciseItem]

    var name: String { L10n.t(zhName, enName) }
    var subtitle: String { L10n.t(zhSubtitle, enSubtitle) }
    var descriptionText: String { L10n.t(zhDescription, enDescription) }
    var difficulty: String { L10n.t(difficultyZh, difficultyEn) }

    // MARK: - Category 1: Push Pull Legs (6 Templates)

    static let pplPushA = BuiltInTemplate(
        id: "ppl_push_strength",
        zhName: "经典推力力量日 (Push A)",
        enName: "Push Power & Strength (A)",
        zhSubtitle: "胸肌 · 前三角肌 · 肱三头肌",
        enSubtitle: "Chest · Front Delts · Triceps",
        zhDescription: "以杠铃卧推为主导力量核心，辅以上斜哑铃与过顶推举，全面锻造推力肌群的绝对爆发与围度。",
        enDescription: "Centred around the Barbell Bench Press for raw pressing power, backed by incline dumbbells and overhead presses.",
        category: .ppl,
        estimatedMinutes: 55,
        difficultyZh: "中高强度",
        difficultyEn: "Intermediate",
        targetMuscles: [.chest, .shoulders, .triceps],
        systemImage: "figure.strengthtraining.traditional",
        items: [
            TemplateExerciseItem(nameEn: "Bench Press", nameZh: "杠铃卧推", targetMuscle: .chest, defaultSets: 4, targetReps: "5-6", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Overhead Press", nameZh: "站姿杠铃推举", targetMuscle: .shoulders, defaultSets: 3, targetReps: "6-8", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Incline Dumbbell Press", nameZh: "上斜哑铃卧推", targetMuscle: .chest, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Lateral Raise", nameZh: "哑铃侧平举", targetMuscle: .shoulders, defaultSets: 4, targetReps: "12-15", supersetGroup: 1),
            TemplateExerciseItem(nameEn: "Tricep Pushdown", nameZh: "绳索下压", targetMuscle: .triceps, defaultSets: 3, targetReps: "10-12", supersetGroup: 1),
        ]
    )

    static let pplPullA = BuiltInTemplate(
        id: "ppl_pull_hypertrophy",
        zhName: "背部厚度与拉力 (Pull A)",
        enName: "Pull Hypertrophy & Thickness (A)",
        zhSubtitle: "传统硬拉 · 杠铃划船 · 二头肌",
        enSubtitle: "Deadlift · Barbell Row · Biceps",
        zhDescription: "重锤硬拉构建下背与全身基底，配合高位下拉与俯身划船雕刻背部肌群厚度与线条。",
        enDescription: "Heavy deadlifts anchor total back foundation, coupled with rows and pulldowns for maximal muscle density.",
        category: .ppl,
        estimatedMinutes: 60,
        difficultyZh: "进阶强度",
        difficultyEn: "Advanced",
        targetMuscles: [.back, .biceps, .shoulders],
        systemImage: "figure.arms.open",
        items: [
            TemplateExerciseItem(nameEn: "Deadlift", nameZh: "传统硬拉", targetMuscle: .back, defaultSets: 4, targetReps: "3-5", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Barbell Row", nameZh: "杠铃划船", targetMuscle: .back, defaultSets: 4, targetReps: "6-8", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Lat Pulldown", nameZh: "高位下拉", targetMuscle: .back, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Face Pull", nameZh: "绳索面拉", targetMuscle: .shoulders, defaultSets: 3, targetReps: "12-15", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Bicep Curl", nameZh: "哑铃弯举", targetMuscle: .biceps, defaultSets: 3, targetReps: "10-12", supersetGroup: nil),
        ]
    )

    static let pplLegsA = BuiltInTemplate(
        id: "ppl_legs_wheels",
        zhName: "下肢深蹲爆发日 (Legs A)",
        enName: "Legs Power & Quads (A)",
        zhSubtitle: "后深蹲 · 罗马尼亚硬拉 · 股四头",
        enSubtitle: "Back Squat · RDL · Quads",
        zhDescription: "力量之根源。以杠铃后深蹲为轴心，辅以腘绳肌与单腿辅助训练，打造磐石般的下肢基座。",
        enDescription: "The engine of physical power. Barbell squats anchored with RDLs and unilateral work.",
        category: .ppl,
        estimatedMinutes: 55,
        difficultyZh: "高强度",
        difficultyEn: "High Intensity",
        targetMuscles: [.quads, .hamstrings, .calves],
        systemImage: "figure.run",
        items: [
            TemplateExerciseItem(nameEn: "Barbell Back Squat", nameZh: "杠铃深蹲", targetMuscle: .quads, defaultSets: 4, targetReps: "5-6", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Romanian Deadlift", nameZh: "罗马尼亚硬拉", targetMuscle: .hamstrings, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Leg Extension", nameZh: "坐姿腿屈伸", targetMuscle: .quads, defaultSets: 3, targetReps: "10-12", supersetGroup: 1),
            TemplateExerciseItem(nameEn: "Seated Leg Curl", nameZh: "坐姿腿弯举", targetMuscle: .hamstrings, defaultSets: 3, targetReps: "10-12", supersetGroup: 1),
            TemplateExerciseItem(nameEn: "Calf Raise", nameZh: "站姿提踵", targetMuscle: .calves, defaultSets: 4, targetReps: "15", supersetGroup: nil),
        ]
    )

    static let pplPushB = BuiltInTemplate(
        id: "ppl_push_chest_focus",
        zhName: "上胸与肩部轰炸 (Push B)",
        enName: "Incline Chest & Delt Forge (B)",
        zhSubtitle: "上斜卧推 · 哑铃推举 · 双杠臂屈伸",
        enSubtitle: "Incline Press · DB OHP · Dips",
        zhDescription: "主攻锁骨上胸与前中三角肌，双杠自重负重加持，塑造饱满铠甲胸膛与宽肩。",
        enDescription: "Focuses on the clavicular upper chest and lateral deltoids for maximum upper-body silhouette.",
        category: .ppl,
        estimatedMinutes: 50,
        difficultyZh: "中阶强度",
        difficultyEn: "Intermediate",
        targetMuscles: [.chest, .shoulders, .triceps],
        systemImage: "figure.strengthtraining.traditional",
        items: [
            TemplateExerciseItem(nameEn: "Incline Bench Press", nameZh: "上斜杠铃卧推", targetMuscle: .chest, defaultSets: 4, targetReps: "6-8", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Dumbbell Shoulder Press", nameZh: "哑铃推举", targetMuscle: .shoulders, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Dip", nameZh: "双杠臂屈伸", targetMuscle: .chest, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Cable Fly", nameZh: "绳索夹胸", targetMuscle: .chest, defaultSets: 3, targetReps: "12-15", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Overhead Tricep Extension", nameZh: "颈后臂屈伸", targetMuscle: .triceps, defaultSets: 3, targetReps: "10-12", supersetGroup: nil),
        ]
    )

    static let pplPullB = BuiltInTemplate(
        id: "ppl_pull_lats_width",
        zhName: "背阔宽度与引体 (Pull B)",
        enName: "V-Taper Lat Width (Pull B)",
        zhSubtitle: "引体向上 · 单臂划船 · 锤式弯举",
        enSubtitle: "Pull-ups · DB Rows · Hammer Curls",
        zhDescription: "专注背阔肌上下外侧纤维延伸，打造经典 V 字型倒三角身材与强悍握力。",
        enDescription: "Targeted lat sweeps and vertical pulling mechanics to build classic V-taper wings.",
        category: .ppl,
        estimatedMinutes: 50,
        difficultyZh: "中高强度",
        difficultyEn: "Intermediate",
        targetMuscles: [.back, .biceps, .shoulders],
        systemImage: "figure.arms.open",
        items: [
            TemplateExerciseItem(nameEn: "Pull-up", nameZh: "引体向上", targetMuscle: .back, defaultSets: 4, targetReps: "6-8", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Single-Arm Dumbbell Row", nameZh: "单臂哑铃划船", targetMuscle: .back, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Seated Cable Row", nameZh: "坐姿划船", targetMuscle: .back, defaultSets: 3, targetReps: "10-12", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Rear Delt Fly", nameZh: "俯身哑铃飞鸟", targetMuscle: .shoulders, defaultSets: 3, targetReps: "12-15", supersetGroup: 1),
            TemplateExerciseItem(nameEn: "Hammer Curl", nameZh: "锤式弯举", targetMuscle: .biceps, defaultSets: 3, targetReps: "10-12", supersetGroup: 1),
        ]
    )

    static let pplLegsB = BuiltInTemplate(
        id: "ppl_legs_posterior",
        zhName: "后侧链与臀腿强化 (Legs B)",
        enName: "Posterior Chain & Glutes (Legs B)",
        zhSubtitle: "杠铃臀推 · 哈克深蹲 · 保加利亚蹲",
        enSubtitle: "Hip Thrust · Hack Squat · Split Squat",
        zhDescription: "重点击溃臀大肌、臀中肌与腘绳肌，提升冲刺硬拉驱动力与膝髋关节稳定性。",
        enDescription: "Isolates glute and hamstring powerhouse drives to support massive deadlift lockouts.",
        category: .ppl,
        estimatedMinutes: 50,
        difficultyZh: "中高强度",
        difficultyEn: "Intermediate",
        targetMuscles: [.glutes, .hamstrings, .quads],
        systemImage: "figure.run",
        items: [
            TemplateExerciseItem(nameEn: "Hip Thrust", nameZh: "杠铃臀推", targetMuscle: .glutes, defaultSets: 4, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Hack Squat", nameZh: "哈克深蹲", targetMuscle: .quads, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Bulgarian Split Squat", nameZh: "保加利亚分腿蹲", targetMuscle: .quads, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Leg Curl", nameZh: "俯卧腿弯举", targetMuscle: .hamstrings, defaultSets: 3, targetReps: "12", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Seated Calf Raise", nameZh: "坐姿提踵", targetMuscle: .calves, defaultSets: 3, targetReps: "15", supersetGroup: nil),
        ]
    )

    // MARK: - Category 2: Upper / Lower Powerbuilding (4 Templates)

    static let ulUpperPower = BuiltInTemplate(
        id: "ul_upper_power",
        zhName: "上肢绝对力量日 (Upper Power)",
        enName: "Upper Power & Strength",
        zhSubtitle: "大重量卧推 · 杠铃划船 · 站姿推举",
        enSubtitle: "Heavy Bench · Rows · OHP",
        zhDescription: "力量举与健美结合的经典上肢力量日。以低次数大重量核心复合动作为主，强化中枢神经募集。",
        enDescription: "Heavy compound power day focusing on low-rep explosive CNS recruitment.",
        category: .upperLower,
        estimatedMinutes: 55,
        difficultyZh: "进阶强度",
        difficultyEn: "Advanced",
        targetMuscles: [.chest, .back, .shoulders, .triceps],
        systemImage: "figure.strengthtraining.traditional",
        items: [
            TemplateExerciseItem(nameEn: "Bench Press", nameZh: "杠铃卧推", targetMuscle: .chest, defaultSets: 5, targetReps: "5", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Barbell Row", nameZh: "杠铃划船", targetMuscle: .back, defaultSets: 4, targetReps: "5", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Overhead Press", nameZh: "站姿杠铃推举", targetMuscle: .shoulders, defaultSets: 3, targetReps: "5", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Chin-up", nameZh: "反手引体向上", targetMuscle: .back, defaultSets: 3, targetReps: "6-8", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Skullcrusher", nameZh: "仰卧臂屈伸", targetMuscle: .triceps, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
        ]
    )

    static let ulLowerPower = BuiltInTemplate(
        id: "ul_lower_power",
        zhName: "下肢绝对力量日 (Lower Power)",
        enName: "Lower Power & Strength",
        zhSubtitle: "深蹲极限 · 重硬拉 · 腿举",
        enSubtitle: "Heavy Squat · Deadlift · Leg Press",
        zhDescription: "深蹲与硬拉同场淬炼，建立不可动摇的下肢与核心骨架力量。",
        enDescription: "Combines squats and heavy pulls to push pure absolute lower-body power ceilings.",
        category: .upperLower,
        estimatedMinutes: 60,
        difficultyZh: "高强度",
        difficultyEn: "High Intensity",
        targetMuscles: [.quads, .hamstrings, .glutes, .core],
        systemImage: "figure.cross.training",
        items: [
            TemplateExerciseItem(nameEn: "Barbell Back Squat", nameZh: "杠铃深蹲", targetMuscle: .quads, defaultSets: 5, targetReps: "5", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Deadlift", nameZh: "传统硬拉", targetMuscle: .back, defaultSets: 3, targetReps: "3-5", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Leg Press", nameZh: "腿举", targetMuscle: .quads, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Hanging Leg Raise", nameZh: "悬垂举腿", targetMuscle: .core, defaultSets: 3, targetReps: "12-15", supersetGroup: nil),
        ]
    )

    static let ulUpperHypertrophy = BuiltInTemplate(
        id: "ul_upper_hypertrophy",
        zhName: "上肢肌肥大循环 (Upper Volume)",
        enName: "Upper Hypertrophy Volume",
        zhSubtitle: "上斜哑铃 · 高位下拉 · 绳索夹胸",
        enSubtitle: "Incline DB · Lat Pulldown · Flyes",
        zhDescription: "高容量与恒定肌肉张力训练，专注目标肌肉泵感与肌纤维微观撕裂再生。",
        enDescription: "High-volume hypertrophy session optimized for metabolic fatigue and continuous tension.",
        category: .upperLower,
        estimatedMinutes: 50,
        difficultyZh: "中阶强度",
        difficultyEn: "Intermediate",
        targetMuscles: [.chest, .back, .shoulders, .biceps, .triceps],
        systemImage: "figure.strengthtraining.traditional",
        items: [
            TemplateExerciseItem(nameEn: "Incline Dumbbell Press", nameZh: "上斜哑铃卧推", targetMuscle: .chest, defaultSets: 4, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Lat Pulldown", nameZh: "高位下拉", targetMuscle: .back, defaultSets: 4, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Machine Shoulder Press", nameZh: "器械推举", targetMuscle: .shoulders, defaultSets: 3, targetReps: "10-12", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Cable Fly", nameZh: "绳索夹胸", targetMuscle: .chest, defaultSets: 3, targetReps: "12-15", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Barbell Curl", nameZh: "杠铃弯举", targetMuscle: .biceps, defaultSets: 3, targetReps: "10-12", supersetGroup: 1),
            TemplateExerciseItem(nameEn: "Tricep Pushdown", nameZh: "绳索下压", targetMuscle: .triceps, defaultSets: 3, targetReps: "10-12", supersetGroup: 1),
        ]
    )

    static let ulLowerHypertrophy = BuiltInTemplate(
        id: "ul_lower_hypertrophy",
        zhName: "下肢肌肥大塑造 (Lower Volume)",
        enName: "Lower Hypertrophy Volume",
        zhSubtitle: "颈前蹲 · 罗马尼亚硬拉 · 分腿蹲",
        enSubtitle: "Front Squat · RDL · Split Squat",
        zhDescription: "强化股四头肌分离度与臀腿过渡线条，兼顾关节灵活性与肌耐力。",
        enDescription: "Targets quad sweeps and teardrops with front squats, split squats, and isolation extensions.",
        category: .upperLower,
        estimatedMinutes: 50,
        difficultyZh: "中高强度",
        difficultyEn: "Intermediate",
        targetMuscles: [.quads, .hamstrings, .glutes, .calves],
        systemImage: "figure.run",
        items: [
            TemplateExerciseItem(nameEn: "Front Squat", nameZh: "颈前深蹲", targetMuscle: .quads, defaultSets: 4, targetReps: "6-8", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Romanian Deadlift", nameZh: "罗马尼亚硬拉", targetMuscle: .hamstrings, defaultSets: 4, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Bulgarian Split Squat", nameZh: "保加利亚分腿蹲", targetMuscle: .quads, defaultSets: 3, targetReps: "10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Leg Extension", nameZh: "坐姿腿屈伸", targetMuscle: .quads, defaultSets: 3, targetReps: "12-15", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Seated Calf Raise", nameZh: "坐姿提踵", targetMuscle: .calves, defaultSets: 3, targetReps: "15", supersetGroup: nil),
        ]
    )

    // MARK: - Category 3: Full Body & Heavy Duty (4 Templates)

    static let fbSquatFocus = BuiltInTemplate(
        id: "fb_squat_focus",
        zhName: "全身力量 A · 深蹲核心",
        enName: "Full Body A · Squat & Press",
        zhSubtitle: "深蹲 · 卧推 · 杠铃划船 · 侧平举",
        enSubtitle: "Squat · Bench · Barbell Row",
        zhDescription: "全身体能基准日。全身大肌群单日高效刺激，极度适合每周 3 练的高频力量增长。",
        enDescription: "Total body cornerstone. Hits all prime movers with high-frequency compound mechanics.",
        category: .fullBody,
        estimatedMinutes: 50,
        difficultyZh: "经典适中",
        difficultyEn: "Classic Intermediate",
        targetMuscles: [.quads, .chest, .back, .shoulders, .core],
        systemImage: "figure.strengthtraining.traditional",
        items: [
            TemplateExerciseItem(nameEn: "Barbell Back Squat", nameZh: "杠铃深蹲", targetMuscle: .quads, defaultSets: 4, targetReps: "5-6", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Bench Press", nameZh: "杠铃卧推", targetMuscle: .chest, defaultSets: 4, targetReps: "5-6", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Barbell Row", nameZh: "杠铃划船", targetMuscle: .back, defaultSets: 3, targetReps: "6-8", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Lateral Raise", nameZh: "哑铃侧平举", targetMuscle: .shoulders, defaultSets: 3, targetReps: "12-15", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Plank", nameZh: "平板支撑", targetMuscle: .core, defaultSets: 3, targetReps: "60s", supersetGroup: nil),
        ]
    )

    static let fbDeadliftFocus = BuiltInTemplate(
        id: "fb_deadlift_focus",
        zhName: "全身力量 B · 硬拉核心",
        enName: "Full Body B · Deadlift & OHP",
        zhSubtitle: "硬拉 · 过顶推举 · 引体向上 · 双杠",
        enSubtitle: "Deadlift · OHP · Pull-up · Dips",
        zhDescription: "硬拉与推举为主轴，搭配自重双杠与引体，拉满背部、肩部与躯干刚性。",
        enDescription: "Heavy ground pulls paired with overhead presses and calisthenic compound staples.",
        category: .fullBody,
        estimatedMinutes: 50,
        difficultyZh: "高强度",
        difficultyEn: "High Intensity",
        targetMuscles: [.back, .shoulders, .chest, .biceps],
        systemImage: "figure.arms.open",
        items: [
            TemplateExerciseItem(nameEn: "Deadlift", nameZh: "传统硬拉", targetMuscle: .back, defaultSets: 4, targetReps: "3-5", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Overhead Press", nameZh: "站姿杠铃推举", targetMuscle: .shoulders, defaultSets: 4, targetReps: "5-6", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Pull-up", nameZh: "引体向上", targetMuscle: .back, defaultSets: 3, targetReps: "6-8", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Dip", nameZh: "双杠臂屈伸", targetMuscle: .chest, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Bicep Curl", nameZh: "哑铃弯举", targetMuscle: .biceps, defaultSets: 3, targetReps: "10-12", supersetGroup: nil),
        ]
    )

    static let fbFrontSquat = BuiltInTemplate(
        id: "fb_front_squat",
        zhName: "全身力量 C · 颈前蹲与推举",
        enName: "Full Body C · Front Squat & Row",
        zhSubtitle: "颈前蹲 · 上斜推胸 · 坐姿划船",
        enSubtitle: "Front Squat · Incline Bench · Row",
        zhDescription: "直立躯干力量挑战。颈前深蹲激活核心与上背支撑，上斜推胸全面增强上身推力。",
        enDescription: "Upright spinal loading via front squats and incline presses for bulletproof core tension.",
        category: .fullBody,
        estimatedMinutes: 45,
        difficultyZh: "中阶强度",
        difficultyEn: "Intermediate",
        targetMuscles: [.quads, .chest, .back, .triceps, .core],
        systemImage: "figure.cross.training",
        items: [
            TemplateExerciseItem(nameEn: "Front Squat", nameZh: "颈前深蹲", targetMuscle: .quads, defaultSets: 4, targetReps: "6-8", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Incline Bench Press", nameZh: "上斜杠铃卧推", targetMuscle: .chest, defaultSets: 4, targetReps: "6-8", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Seated Cable Row", nameZh: "坐姿划船", targetMuscle: .back, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Tricep Pushdown", nameZh: "绳索下压", targetMuscle: .triceps, defaultSets: 3, targetReps: "10-12", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Cable Crunch", nameZh: "绳索卷腹", targetMuscle: .core, defaultSets: 3, targetReps: "15", supersetGroup: nil),
        ]
    )

    static let fbMinimalist = BuiltInTemplate(
        id: "fb_minimalist",
        zhName: "极简高效 45 分钟全身",
        enName: "Minimalist 45-Min Heavy Duty",
        zhSubtitle: "三大项 + 引体 · 纯粹力量精粹",
        enSubtitle: "Squat · Bench · Pull-up · 45m",
        zhDescription: "时间紧迫铁友的首选。剔除一切花哨孤立，只留最硬核的 4 大复合动作。",
        enDescription: "Zero fluff. Just the raw essentials of barbell power for time-crunched lifters.",
        category: .fullBody,
        estimatedMinutes: 45,
        difficultyZh: "高强度",
        difficultyEn: "High Intensity",
        targetMuscles: [.quads, .chest, .back],
        systemImage: "hammer.fill",
        items: [
            TemplateExerciseItem(nameEn: "Barbell Back Squat", nameZh: "杠铃深蹲", targetMuscle: .quads, defaultSets: 4, targetReps: "5", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Bench Press", nameZh: "杠铃卧推", targetMuscle: .chest, defaultSets: 4, targetReps: "5", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Chin-up", nameZh: "反手引体向上", targetMuscle: .back, defaultSets: 3, targetReps: "Max", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Romanian Deadlift", nameZh: "罗马尼亚硬拉", targetMuscle: .hamstrings, defaultSets: 3, targetReps: "6-8", supersetGroup: nil),
        ]
    )

    // MARK: - Category 4: Powerlifting SBD & Peaks (4 Templates)

    static let sbdBigThree = BuiltInTemplate(
        id: "sbd_big_three",
        zhName: "力量举三大项测验日 (SBD)",
        enName: "The Big 3 Total Test (SBD)",
        zhSubtitle: "深蹲 · 卧推 · 硬拉 · 极限冲刺",
        enSubtitle: "Squat · Bench · Deadlift · Max Test",
        zhDescription: "公证见证的最高殿堂。单日依次测试深蹲、卧推、硬拉极限 1RM，计算最权威的 DOTS 力量分！",
        enDescription: "The ultimate proving ground. Tests Squat, Bench, and Deadlift 1RM for certified DOTS scoring.",
        category: .powerlifting,
        estimatedMinutes: 65,
        difficultyZh: "极限强度",
        difficultyEn: "Max Peak Test",
        targetMuscles: [.quads, .chest, .back, .glutes],
        systemImage: "trophy.fill",
        items: [
            TemplateExerciseItem(nameEn: "Barbell Back Squat", nameZh: "杠铃深蹲", targetMuscle: .quads, defaultSets: 5, targetReps: "3-1RM", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Bench Press", nameZh: "杠铃卧推", targetMuscle: .chest, defaultSets: 5, targetReps: "3-1RM", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Deadlift", nameZh: "传统硬拉", targetMuscle: .back, defaultSets: 5, targetReps: "3-1RM", supersetGroup: nil),
        ]
    )

    static let sbdBenchSpecialist = BuiltInTemplate(
        id: "sbd_bench_specialist",
        zhName: "卧推突破与上身力矩",
        enName: "Bench Press Lockout Specialist",
        zhSubtitle: "重卧推 · 窄卧推 · 哑铃推 · 面拉",
        enSubtitle: "Heavy Bench · Close Grip · DB Press",
        zhDescription: "攻克卧推粘滞点。通过窄握强化肱三头肌锁死爆发力，上背与后束提供坚实卧推支撑基底。",
        enDescription: "Breaks bench press plateaus by drilling lockout tricep drive and scapular stability.",
        category: .powerlifting,
        estimatedMinutes: 50,
        difficultyZh: "中高强度",
        difficultyEn: "Intermediate",
        targetMuscles: [.chest, .triceps, .shoulders, .back],
        systemImage: "figure.strengthtraining.traditional",
        items: [
            TemplateExerciseItem(nameEn: "Bench Press", nameZh: "杠铃卧推", targetMuscle: .chest, defaultSets: 5, targetReps: "3-5", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Close-Grip Bench Press", nameZh: "窄距卧推", targetMuscle: .triceps, defaultSets: 4, targetReps: "6-8", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Incline Dumbbell Press", nameZh: "上斜哑铃卧推", targetMuscle: .chest, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Face Pull", nameZh: "绳索面拉", targetMuscle: .shoulders, defaultSets: 4, targetReps: "12-15", supersetGroup: nil),
        ]
    )

    static let sbdSquatSpecialist = BuiltInTemplate(
        id: "sbd_squat_specialist",
        zhName: "深蹲突破与核心支点",
        enName: "Squat Depth & Drive Specialist",
        zhSubtitle: "后蹲 · 颈前蹲 · 早安式 · 腿举",
        enSubtitle: "Back Squat · Front Squat · Good Mornings",
        zhDescription: "打破深蹲下陷粘滞点。颈前蹲保持躯干竖直，早安式强化下背髋部铰链，助力深蹲吨位跃升。",
        enDescription: "Eliminates the squat sticking point with front squat mechanics and posterior chain bracing.",
        category: .powerlifting,
        estimatedMinutes: 55,
        difficultyZh: "进阶强度",
        difficultyEn: "Advanced",
        targetMuscles: [.quads, .hamstrings, .core],
        systemImage: "figure.run",
        items: [
            TemplateExerciseItem(nameEn: "Barbell Back Squat", nameZh: "杠铃深蹲", targetMuscle: .quads, defaultSets: 5, targetReps: "3-5", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Front Squat", nameZh: "颈前深蹲", targetMuscle: .quads, defaultSets: 3, targetReps: "5-6", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Good Morning", nameZh: "早安式", targetMuscle: .hamstrings, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Ab Wheel Rollout", nameZh: "健腹轮", targetMuscle: .core, defaultSets: 3, targetReps: "10-12", supersetGroup: nil),
        ]
    )

    static let sbdDeadliftBuilder = BuiltInTemplate(
        id: "sbd_deadlift_builder",
        zhName: "硬拉锁死与背部铁壁",
        enName: "Deadlift Lockout & Back Builder",
        zhSubtitle: "大重量拉 · 罗马尼亚 · T杠划船 · 耸肩",
        enSubtitle: "Heavy Pulls · RDL · T-Bar Row · Shrugs",
        zhDescription: "强化启动离地与顶端锁髋。T 杠划船与耸肩打造厚实上背斜方肌，杜绝大重量弯腰脱手。",
        enDescription: "Builds absolute pulling dominance off the floor and impenetrable upper back tightness.",
        category: .powerlifting,
        estimatedMinutes: 55,
        difficultyZh: "进阶强度",
        difficultyEn: "Advanced",
        targetMuscles: [.back, .hamstrings, .shoulders],
        systemImage: "figure.arms.open",
        items: [
            TemplateExerciseItem(nameEn: "Deadlift", nameZh: "传统硬拉", targetMuscle: .back, defaultSets: 5, targetReps: "2-4", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Romanian Deadlift", nameZh: "罗马尼亚硬拉", targetMuscle: .hamstrings, defaultSets: 3, targetReps: "6-8", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "T-Bar Row", nameZh: "T杠划船", targetMuscle: .back, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Barbell Shrug", nameZh: "杠铃耸肩", targetMuscle: .shoulders, defaultSets: 3, targetReps: "12-15", supersetGroup: nil),
        ]
    )

    // MARK: - Category 5: Specialization & Body-Part Focus (6 Templates)

    static let specGoldenEraChest = BuiltInTemplate(
        id: "spec_golden_era_chest",
        zhName: "黄金年代 · 饱满胸肌特化",
        enName: "Golden Era Chest Forge",
        zhSubtitle: "杠铃卧推 · 上斜哑铃 · 双杠 · 飞鸟",
        enSubtitle: "Bench · Incline DB · Dips · Flyes",
        zhDescription: "传承古典黄金时代的胸肌雕刻哲学。全角度覆盖上中下胸与中缝挤压，打造方型盔甲胸。",
        enDescription: "Classic bodybuilding chest routine hitting all angles from clavicular to sternal heads.",
        category: .specialization,
        estimatedMinutes: 50,
        difficultyZh: "中高强度",
        difficultyEn: "Intermediate",
        targetMuscles: [.chest, .triceps],
        systemImage: "figure.strengthtraining.traditional",
        items: [
            TemplateExerciseItem(nameEn: "Bench Press", nameZh: "杠铃卧推", targetMuscle: .chest, defaultSets: 4, targetReps: "6-8", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Incline Dumbbell Press", nameZh: "上斜哑铃卧推", targetMuscle: .chest, defaultSets: 4, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Dip", nameZh: "双杠臂屈伸", targetMuscle: .chest, defaultSets: 3, targetReps: "10-12", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Pec Deck", nameZh: "蝴蝶机夹胸", targetMuscle: .chest, defaultSets: 3, targetReps: "12-15", supersetGroup: 1),
            TemplateExerciseItem(nameEn: "Push-up", nameZh: "俯卧撑", targetMuscle: .chest, defaultSets: 3, targetReps: "力竭 / Max", supersetGroup: 1),
        ]
    )

    static let specVTaperBack = BuiltInTemplate(
        id: "spec_v_taper_back",
        zhName: "倒三角 · 宽厚背部特化",
        enName: "V-Taper Lat Width & Thickness",
        zhSubtitle: "正手引体 · 杠铃划船 · 直臂下压",
        enSubtitle: "Pull-ups · Barbell Rows · Pulldowns",
        zhDescription: "专注展开背阔肌大翼与加厚大圆肌、中下斜方肌，让腰显得更细，倒三角视觉冲击拉满。",
        enDescription: "Designed for dramatic lat width and mid-back rhomboid density to maximize the V-taper frame.",
        category: .specialization,
        estimatedMinutes: 50,
        difficultyZh: "中高强度",
        difficultyEn: "Intermediate",
        targetMuscles: [.back, .biceps],
        systemImage: "figure.arms.open",
        items: [
            TemplateExerciseItem(nameEn: "Pull-up", nameZh: "引体向上", targetMuscle: .back, defaultSets: 4, targetReps: "6-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Barbell Row", nameZh: "杠铃划船", targetMuscle: .back, defaultSets: 4, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Lat Pulldown", nameZh: "高位下拉", targetMuscle: .back, defaultSets: 3, targetReps: "10-12", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Straight-Arm Pulldown", nameZh: "直臂下压", targetMuscle: .back, defaultSets: 3, targetReps: "12-15", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Chest-Supported Row", nameZh: "上斜凳哑铃划船", targetMuscle: .back, defaultSets: 3, targetReps: "10-12", supersetGroup: nil),
        ]
    )

    static let specBoulderShoulders = BuiltInTemplate(
        id: "spec_boulder_shoulders",
        zhName: "球形南瓜肩 · 3D 轰炸",
        enName: "Boulder 3D Deltoid Forge",
        zhSubtitle: "站姿推举 · 侧平举 · 阿诺德 · 俯身飞鸟",
        enSubtitle: "OHP · Lateral Raises · Rear Delts",
        zhDescription: "前束、中束、后束全方位饱满打造，重点增加中束飞鸟容量，让肩部呈现立体球形倒角。",
        enDescription: "Complete 3D shoulder sculpting covering anterior, lateral, and posterior heads.",
        category: .specialization,
        estimatedMinutes: 45,
        difficultyZh: "中阶强度",
        difficultyEn: "Intermediate",
        targetMuscles: [.shoulders, .triceps],
        systemImage: "figure.strengthtraining.traditional",
        items: [
            TemplateExerciseItem(nameEn: "Overhead Press", nameZh: "站姿杠铃推举", targetMuscle: .shoulders, defaultSets: 4, targetReps: "6-8", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Lateral Raise", nameZh: "哑铃侧平举", targetMuscle: .shoulders, defaultSets: 4, targetReps: "12-15", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Arnold Press", nameZh: "阿诺德推举", targetMuscle: .shoulders, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Rear Delt Fly", nameZh: "俯身哑铃飞鸟", targetMuscle: .shoulders, defaultSets: 4, targetReps: "15", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Barbell Shrug", nameZh: "杠铃耸肩", targetMuscle: .shoulders, defaultSets: 3, targetReps: "12", supersetGroup: nil),
        ]
    )

    static let specArmSuperset = BuiltInTemplate(
        id: "spec_arm_superset",
        zhName: "手臂双峰 · 二三头超级组",
        enName: "Arm Day Superset Forge",
        zhSubtitle: "杠铃弯举 × 仰卧臂屈伸 · 泵感拉满",
        enSubtitle: "Barbell Curls × Skullcrushers",
        zhDescription: "二头与三头肌拮抗超级组训练。节省时间的同时，让双臂充血泵感达到极致，撑爆袖口。",
        enDescription: "Antagonist arm supersets delivering intense blood flow, vascularity, and peak contraction.",
        category: .specialization,
        estimatedMinutes: 40,
        difficultyZh: "中阶强度",
        difficultyEn: "Intermediate",
        targetMuscles: [.biceps, .triceps],
        systemImage: "bolt.fill",
        items: [
            TemplateExerciseItem(nameEn: "Barbell Curl", nameZh: "杠铃弯举", targetMuscle: .biceps, defaultSets: 4, targetReps: "8-10", supersetGroup: 1),
            TemplateExerciseItem(nameEn: "Skullcrusher", nameZh: "仰卧臂屈伸", targetMuscle: .triceps, defaultSets: 4, targetReps: "8-10", supersetGroup: 1),
            TemplateExerciseItem(nameEn: "Hammer Curl", nameZh: "锤式弯举", targetMuscle: .biceps, defaultSets: 3, targetReps: "10-12", supersetGroup: 2),
            TemplateExerciseItem(nameEn: "Tricep Pushdown", nameZh: "绳索下压", targetMuscle: .triceps, defaultSets: 3, targetReps: "10-12", supersetGroup: 2),
            TemplateExerciseItem(nameEn: "Preacher Curl", nameZh: "牧师凳弯举", targetMuscle: .biceps, defaultSets: 3, targetReps: "12", supersetGroup: 3),
            TemplateExerciseItem(nameEn: "Overhead Cable Extension", nameZh: "绳索颈后臂屈伸", targetMuscle: .triceps, defaultSets: 3, targetReps: "12", supersetGroup: 3),
        ]
    )

    static let specGluteHamstring = BuiltInTemplate(
        id: "spec_glute_hamstring",
        zhName: "臀部与腘绳肌塑形",
        enName: "Glutes & Hamstrings Hypertrophy",
        zhSubtitle: "杠铃臀推 · 罗马尼亚硬拉 · 绳索后踢",
        enSubtitle: "Hip Thrust · RDL · Kickbacks",
        zhDescription: "专注臀大肌、臀中肌上部饱满度与大腿后侧腘绳肌线条，深层激活髋伸爆发力。",
        enDescription: "Focused hip extension and posterior chain sculpting for glute mass and hamstring tie-ins.",
        category: .specialization,
        estimatedMinutes: 45,
        difficultyZh: "中阶强度",
        difficultyEn: "Intermediate",
        targetMuscles: [.glutes, .hamstrings],
        systemImage: "figure.run",
        items: [
            TemplateExerciseItem(nameEn: "Hip Thrust", nameZh: "杠铃臀推", targetMuscle: .glutes, defaultSets: 4, targetReps: "10-12", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Romanian Deadlift", nameZh: "罗马尼亚硬拉", targetMuscle: .hamstrings, defaultSets: 3, targetReps: "8-10", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Cable Kickback", nameZh: "绳索后踢", targetMuscle: .glutes, defaultSets: 3, targetReps: "12-15", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Seated Leg Curl", nameZh: "坐姿腿弯举", targetMuscle: .hamstrings, defaultSets: 3, targetReps: "12-15", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Hip Abductor Machine", nameZh: "坐姿髋外展", targetMuscle: .glutes, defaultSets: 3, targetReps: "15-20", supersetGroup: nil),
        ]
    )

    static let specCoreCalves = BuiltInTemplate(
        id: "spec_core_calves",
        zhName: "铁打核心与小腿爆发",
        enName: "Core Fortress & Calves",
        zhSubtitle: "悬垂举腿 · 绳索卷腹 · 健腹轮 · 提踵",
        enSubtitle: "Hanging Leg Raise · Ab Wheel · Calves",
        zhDescription: "建立如同钢板般的前后侧核心刚度，辅以小腿肌群高次数泵感，全面补齐力量死角。",
        enDescription: "Total trunk rigidity training with multi-angle core braces and high-frequency calf training.",
        category: .specialization,
        estimatedMinutes: 35,
        difficultyZh: "入门到进阶",
        difficultyEn: "All Levels",
        targetMuscles: [.core, .calves],
        systemImage: "shield.fill",
        items: [
            TemplateExerciseItem(nameEn: "Hanging Leg Raise", nameZh: "悬垂举腿", targetMuscle: .core, defaultSets: 4, targetReps: "12-15", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Cable Crunch", nameZh: "绳索卷腹", targetMuscle: .core, defaultSets: 3, targetReps: "15", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Ab Wheel Rollout", nameZh: "健腹轮", targetMuscle: .core, defaultSets: 3, targetReps: "10-12", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Calf Raise", nameZh: "站姿提踵", targetMuscle: .calves, defaultSets: 4, targetReps: "15-20", supersetGroup: nil),
            TemplateExerciseItem(nameEn: "Plank", nameZh: "平板支撑", targetMuscle: .core, defaultSets: 3, targetReps: "60s", supersetGroup: nil),
        ]
    )

    // MARK: - Full 24-Template Registry

    static let all: [BuiltInTemplate] = [
        // PPL (6)
        pplPushA,
        pplPullA,
        pplLegsA,
        pplPushB,
        pplPullB,
        pplLegsB,

        // Upper / Lower (4)
        ulUpperPower,
        ulLowerPower,
        ulUpperHypertrophy,
        ulLowerHypertrophy,

        // Full Body (4)
        fbSquatFocus,
        fbDeadliftFocus,
        fbFrontSquat,
        fbMinimalist,

        // Powerlifting SBD (4)
        sbdBigThree,
        sbdBenchSpecialist,
        sbdSquatSpecialist,
        sbdDeadliftBuilder,

        // Specialization (6)
        specGoldenEraChest,
        specVTaperBack,
        specBoulderShoulders,
        specArmSuperset,
        specGluteHamstring,
        specCoreCalves
    ]
}
