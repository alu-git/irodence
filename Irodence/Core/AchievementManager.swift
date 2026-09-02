import SwiftUI

/// Manages achievement evaluation, unlock persistence, and the reveal queue across workout completion.
@MainActor
final class AchievementManager: ObservableObject {
    static let shared = AchievementManager()

    @Published private(set) var currentReveal: AchievementItem?
    @Published private(set) var sessionAchievements: [AchievementItem] = []

    private let unlockedKey = "unlockedAchievementIDs"
    private let pendingQueueKey = "pendingAchievementRevealQueue"

    private var unshownCountThisSession = 0
    private let maxModalsPerSession = 2

    init() {
        restorePendingQueueIfNeeded()
    }

    /// Evaluates the finished workout summary and returns an ordered list of newly unlocked achievements.
    /// Order: Tier-ups first, then First-times, then Milestones.
    func evaluateSession(summary: WorkoutManager.Summary, userID: UUID) -> [AchievementItem] {
        var unlockedNow: [AchievementItem] = []
        var existingIDs = getUnlockedIDs()

        // 1. Tier-Up evaluation for actual completed exercises in this session
        if !summary.completedExercises.isEmpty {
            for ex in summary.completedExercises {
                let achievement = AchievementCatalog.tierUp(
                    tier: ex.achievedTier,
                    lift: ex.exercise.coreLift,
                    exerciseName: ex.exercise.primaryName
                )
                if !unlockedNow.contains(where: { $0.id == achievement.id }) {
                    unlockedNow.append(achievement)
                    existingIDs.insert(achievement.id)
                }
            }
        } else if let moment = summary.tierMoment {
            let achievement = AchievementCatalog.tierUp(tier: moment.tier, lift: moment.lift)
            if !unlockedNow.contains(where: { $0.id == achievement.id }) {
                unlockedNow.append(achievement)
                existingIDs.insert(achievement.id)
            }
        }

        // 2. First PR evaluation
        if !summary.prs.isEmpty {
            let prAch = AchievementCatalog.firstPR
            if !existingIDs.contains(prAch.id) {
                unlockedNow.append(prAch)
                existingIDs.insert(prAch.id)
            }
        }

        // 3. First Workout evaluation
        if summary.completedSets > 0 {
            let fwAch = AchievementCatalog.firstWorkout
            if !existingIDs.contains(fwAch.id) {
                unlockedNow.append(fwAch)
                existingIDs.insert(fwAch.id)
            }
        }

        // 4. Milestone: Volume >= 10,000 kg
        if summary.totalVolumeKg >= 10_000 {
            let volAch = AchievementCatalog.volume10Tons
            if !existingIDs.contains(volAch.id) {
                unlockedNow.append(volAch)
                existingIDs.insert(volAch.id)
            }
        }

        // 5. Milestone: Streak >= 4 weeks
        if summary.streakWeeks >= 4 {
            let strAch = AchievementCatalog.streak4Weeks
            if !existingIDs.contains(strAch.id) {
                unlockedNow.append(strAch)
                existingIDs.insert(strAch.id)
            }
        }

        // Order: Tier-up (0) -> First-time (1) -> Milestone (2)
        unlockedNow.sort { $0.category.sortOrder < $1.category.sortOrder }

        // Save newly unlocked
        saveUnlockedIDs(existingIDs)

        self.sessionAchievements = unlockedNow
        self.unshownCountThisSession = 0

        // Queue reveals (up to max 2 modals)
        let queueItems = Array(unlockedNow.prefix(maxModalsPerSession))
        savePendingQueue(queueItems)

        return unlockedNow
    }

    /// Triggers presentation of the first modal in the queue after workout completion.
    func startRevealSequence() {
        restorePendingQueueIfNeeded()
    }

    /// Called when user taps "收下" on the current reveal modal.
    /// Pops the queue and presents the next modal if under the 2-reveal limit.
    func dismissCurrentAndPresentNext() {
        var queue = getPendingQueue()
        if !queue.isEmpty {
            queue.removeFirst()
            savePendingQueue(queue)
        }

        if let next = queue.first, unshownCountThisSession < maxModalsPerSession {
            unshownCountThisSession += 1
            currentReveal = next
        } else {
            currentReveal = nil
            clearPendingQueue()
        }
    }

    /// Replay any achievement reveal modal on demand (e.g. from strip tap).
    func replayReveal(_ achievement: AchievementItem) {
        currentReveal = achievement
    }

    /// Restores unshown reveals if the user backgrounds and foregrounds the app.
    func restorePendingQueueIfNeeded() {
        let queue = getPendingQueue()
        if let first = queue.first, currentReveal == nil {
            currentReveal = first
            unshownCountThisSession = 1
        }
    }

    // MARK: - Persistence Helpers

    private func getUnlockedIDs() -> Set<String> {
        let raw = UserDefaults.standard.string(forKey: unlockedKey) ?? ""
        return Set(raw.split(separator: ",").map(String.init))
    }

    private func saveUnlockedIDs(_ ids: Set<String>) {
        let raw = ids.joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: unlockedKey)
    }

    private func getPendingQueue() -> [AchievementItem] {
        guard let data = UserDefaults.standard.data(forKey: pendingQueueKey),
              let list = try? JSONDecoder().decode([AchievementItem].self, from: data) else {
            return []
        }
        return list
    }

    private func savePendingQueue(_ items: [AchievementItem]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: pendingQueueKey)
        }
    }

    private func clearPendingQueue() {
        UserDefaults.standard.removeObject(forKey: pendingQueueKey)
    }
}
