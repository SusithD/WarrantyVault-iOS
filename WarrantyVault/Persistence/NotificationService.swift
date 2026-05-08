import Foundation
import UserNotifications

/// Wraps `UNUserNotificationCenter` with a small API tailored to warranty
/// expiry reminders. Up to four pending requests per warranty (`-30`, `-7`,
/// `-1`, `0` days from expiry); past fire dates are dropped.
final class NotificationService {

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    /// Offsets (in days) from the warranty's expiry date.
    /// Negative = before expiry. `0` = on expiry day.
    private let offsetsInDays: [Int] = [-30, -7, -1, 0]

    // MARK: - Authorization

    /// Asks the user for `[.alert, .badge, .sound]` if the current status is
    /// `.notDetermined`. Returns whether the app is authorised after the call.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                return false
            }
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Schedule / cancel

    /// Schedule the four expiry reminders for a warranty. No-op if the warranty
    /// has reminders disabled or the user has not authorised notifications.
    /// Existing requests for the same warranty are replaced.
    func schedule(for warranty: Warranty) async {
        cancel(for: warranty.id)

        guard warranty.reminderEnabled else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral
        else { return }

        let now = Date()
        let calendar = Calendar.current

        for offset in offsetsInDays {
            guard let fireDate = calendar.date(byAdding: .day, value: offset, to: warranty.expiryDate),
                  fireDate > now
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = title(for: offset, warranty: warranty)
            content.body  = body(for: offset, warranty: warranty)
            content.sound = .default
            content.userInfo = [
                "warrantyId": warranty.id.uuidString,
                "offsetDays": offset
            ]

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let request = UNNotificationRequest(
                identifier: identifier(for: warranty.id, offset: offset),
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                // Swallow individual scheduling errors; one bad request shouldn't abort the rest.
                continue
            }
        }
    }

    /// Removes any pending requests previously scheduled for `warrantyId`.
    func cancel(for warrantyId: UUID) {
        let ids = offsetsInDays.map { identifier(for: warrantyId, offset: $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Snapshot of pending requests — useful for tests and diagnostics.
    func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    // MARK: - Helpers

    private func identifier(for warrantyId: UUID, offset: Int) -> String {
        "warranty.\(warrantyId.uuidString).\(offset)"
    }

    private func title(for offset: Int, warranty: Warranty) -> String {
        switch offset {
        case 0:   return "Warranty expiring today"
        case -1:  return "Warranty expires tomorrow"
        case -7:  return "Warranty expires in 7 days"
        case -30: return "Warranty expires in 30 days"
        default:  return "Warranty reminder"
        }
    }

    private func body(for offset: Int, warranty: Warranty) -> String {
        switch offset {
        case 0:
            return "\(warranty.productName) coverage ends today. File any pending claim now."
        case -1:
            return "\(warranty.productName) coverage ends tomorrow."
        default:
            return "\(warranty.productName) coverage from \(warranty.retailer) is ending soon."
        }
    }
}
