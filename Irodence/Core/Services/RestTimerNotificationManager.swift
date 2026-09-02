import Foundation
import UserNotifications

/// Schedules and manages background local notifications for the active workout rest timer.
public enum RestTimerNotificationManager {
    private static let timerNotificationID = "irodence_rest_timer_alert"

    /// Requests authorization for alerts & sounds.
    public static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            #if DEBUG
            if let error {
                print("[RestTimerNotification] Authorization error: \(error.localizedDescription)")
            }
            #endif
        }
    }

    /// Schedules a local notification when rest ends.
    public static func scheduleRestNotification(endsAt: Date, nextExerciseName: String? = nil) {
        let remaining = endsAt.timeIntervalSinceNow
        guard remaining > 1 else { return }

        // Cancel any pending timer notification first
        cancelRestNotification()

        let content = UNMutableNotificationContent()
        content.title = L10n.t("铁证 · 休息倒计时结束", "Rest Complete")
        
        if let next = nextExerciseName, !next.isEmpty {
            content.body = L10n.t("下组准备：\(next)，继续锻造！", "Next up: \(next). Time to lift!")
        } else {
            content.body = L10n.t("组间休息结束，准备开始下一组！", "Rest time is up — time for your next set!")
        }
        
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        let request = UNNotificationRequest(identifier: timerNotificationID, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            #if DEBUG
            if let error {
                print("[RestTimerNotification] Failed to schedule notification: \(error.localizedDescription)")
            }
            #endif
        }
    }

    /// Cancels any active rest timer notification (e.g. user skipped or finished set early).
    public static func cancelRestNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timerNotificationID])
    }
}
