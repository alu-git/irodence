import Foundation
import SwiftUI
import Combine

/// Manages casual gym moments feed, publishing, reactions (碰拳 👊 & 加炭 🔥).
@MainActor
final class GymMomentService: ObservableObject {
    @Published private(set) var moments: [GymMoment] = []
    @Published private(set) var isLoading = false

    private static let cacheKey = "gym_moments_cache"

    init() {
        if let cached: [GymMoment] = DiskCache.load([GymMoment].self, key: Self.cacheKey), !cached.isEmpty {
            moments = cached
        } else {
            moments = Self.defaultMoments
            DiskCache.save(moments, key: Self.cacheKey)
        }
    }

    func fetchMoments() async {
        isLoading = moments.isEmpty
        // Network simulation / backend fetch
        try? await Task.sleep(nanoseconds: 300_000_000)
        if moments.isEmpty {
            moments = Self.defaultMoments
        }
        DiskCache.save(moments, key: Self.cacheKey)
        isLoading = false
    }

    func publishMoment(
        userID: UUID,
        userDisplayName: String,
        userTierName: String? = "熟铁",
        userCrewName: String? = nil,
        visibilityText: String? = "仅熔炉可见",
        imageData: Data?,
        caption: String?,
        workoutName: String? = "训练日",
        workoutDurationText: String?,
        workoutVolumeText: String?,
        tags: [String] = []
    ) {
        let newMoment = GymMoment(
            id: UUID(),
            userID: userID,
            userDisplayName: userDisplayName,
            userTierName: userTierName,
            userCrewName: userCrewName ?? L10n.t("玄铁重工", "Dark Iron"),
            visibilityText: visibilityText ?? L10n.t("仅熔炉可见", "Crew Only"),
            imageURL: nil,
            localImageData: imageData,
            caption: caption,
            workoutName: workoutName,
            workoutDurationText: workoutDurationText,
            workoutVolumeText: workoutVolumeText,
            tags: tags,
            fistBumpCount: 0,
            fistBumpedByMe: false,
            fireCount: 1,
            firedByMe: true,
            commentCount: 0,
            createdAt: Date()
        )
        moments.insert(newMoment, at: 0)
        DiskCache.save(moments, key: Self.cacheKey)
    }

    func toggleFistBump(momentID: UUID) {
        guard let index = moments.firstIndex(where: { $0.id == momentID }) else { return }
        if moments[index].fistBumpedByMe {
            moments[index].fistBumpedByMe = false
            moments[index].fistBumpCount = max(0, moments[index].fistBumpCount - 1)
        } else {
            moments[index].fistBumpedByMe = true
            moments[index].fistBumpCount += 1
            ForgeHaptics.strike()
        }
        DiskCache.save(moments, key: Self.cacheKey)
    }

    func toggleFire(momentID: UUID) {
        guard let index = moments.firstIndex(where: { $0.id == momentID }) else { return }
        if moments[index].firedByMe {
            moments[index].firedByMe = false
            moments[index].fireCount = max(0, moments[index].fireCount - 1)
        } else {
            moments[index].firedByMe = true
            moments[index].fireCount += 1
            ForgeHaptics.strike()
        }
        DiskCache.save(moments, key: Self.cacheKey)
    }

    // MARK: - Realistic Default Seed Moments

    static var defaultMoments: [GymMoment] {
        [
            GymMoment(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222200")!,
                userID: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
                userDisplayName: L10n.t("我 (铁骨淬火者)", "Me (Iron Forger)"),
                userTierName: "铸钢",
                userCrewName: L10n.t("玄铁重工", "Dark Iron"),
                visibilityText: L10n.t("公开见证", "Public Proof"),
                imageURL: nil,
                localImageData: nil,
                caption: L10n.t("今日淬火完成！卧推突破新纪录，力量渐入佳境，继续向精钢迈进。", "Workout completed! Broke a new bench press PR today, onward to refined steel."),
                workoutName: "推力力量日",
                workoutDurationText: "55m",
                workoutVolumeText: "容量 9.8t",
                tags: ["#新纪录PR", "#今日淬火完成"],
                fistBumpCount: 38,
                fistBumpedByMe: true,
                fireCount: 76,
                firedByMe: true,
                commentCount: 9,
                createdAt: Date().addingTimeInterval(-900)
            ),
            GymMoment(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222201")!,
                userID: UUID(uuidString: "22222222-2222-2222-2222-222222222202")!,
                userDisplayName: "麦昆",
                userTierName: "熟铁",
                userCrewName: L10n.t("闪电车队", "Lightning Squad"),
                visibilityText: L10n.t("仅熔炉可见", "Crew Only"),
                imageURL: nil,
                localImageData: nil,
                caption: L10n.t("经典推力日完成，最后一组双杠彻底拉爆", "Push day crushed, final dip sets pushed to total failure"),
                workoutName: "推力日",
                workoutDurationText: "1h 15m",
                workoutVolumeText: "容量 8.4t",
                tags: ["#练后泵感", "#推力力量日"],
                fistBumpCount: 24,
                fistBumpedByMe: true,
                fireCount: 58,
                firedByMe: false,
                commentCount: 8,
                createdAt: Date().addingTimeInterval(-1800)
            ),
            GymMoment(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222203")!,
                userID: UUID(uuidString: "22222222-2222-2222-2222-222222222204")!,
                userDisplayName: "琳琳",
                userTierName: "精钢",
                userCrewName: L10n.t("大力菠菜营", "Popeye Camp"),
                visibilityText: L10n.t("仅熔炉可见", "Crew Only"),
                imageURL: nil,
                localImageData: nil,
                caption: L10n.t("早起练背，今天引体负重 20kg 感觉轻如鸿毛。同炉铁友冲！", "Early morning back session! Weighted pullups +20kg felt like feathers today."),
                workoutName: "拉力日",
                workoutDurationText: "50m",
                workoutVolumeText: "容量 6.2t",
                tags: ["#晨练打卡", "#拉力日"],
                fistBumpCount: 19,
                fistBumpedByMe: false,
                fireCount: 42,
                firedByMe: true,
                commentCount: 5,
                createdAt: Date().addingTimeInterval(-7200)
            ),
            GymMoment(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222205")!,
                userID: UUID(uuidString: "22222222-2222-2222-2222-222222222206")!,
                userDisplayName: "铁馆老王",
                userTierName: "重锻",
                userCrewName: L10n.t("钢铁之翼", "Steel Wing"),
                visibilityText: L10n.t("社区公开", "Public"),
                imageURL: nil,
                localImageData: nil,
                caption: L10n.t("练腿日必须要有一顿足量的牛肉和碳水淬火。生锈必催！", "Leg day fuel! Quality beef and carb reload post-squat."),
                workoutName: "蹲腿日",
                workoutDurationText: "1h 30m",
                workoutVolumeText: "容量 14.5t",
                tags: ["#蹲腿日", "#硬核营养"],
                fistBumpCount: 36,
                fistBumpedByMe: false,
                fireCount: 88,
                firedByMe: false,
                commentCount: 12,
                createdAt: Date().addingTimeInterval(-14400)
            )
        ]
    }
}
