import Foundation
import EventKit

/// Wraps `EKEventStore` for warranty-expiry calendar sync.
/// Always uses the default calendar; one all-day event per warranty with a 9 AM alarm.
final class CalendarService {

    static let shared = CalendarService()

    enum Failure: Error {
        case authorizationDenied
        case noDefaultCalendar
        case underlying(Error)
    }

    private let store = EKEventStore()

    // MARK: - Authorization

    /// Asks for full-access calendar permission if not yet decided.
    /// Returns whether the app currently has full access after the call.
    @discardableResult
    func requestAccessIfNeeded() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return true
        case .notDetermined:
            do {
                return try await store.requestFullAccessToEvents()
            } catch {
                return false
            }
        case .denied, .restricted, .writeOnly:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Mutations

    /// Creates or updates the calendar event for a warranty. Returns the
    /// resulting event identifier — store it on the warranty for later updates.
    /// Returns `nil` if calendar access is denied.
    func upsertEvent(for warranty: Warranty) async throws -> String? {
        guard await requestAccessIfNeeded() else { throw Failure.authorizationDenied }
        guard let calendar = store.defaultCalendarForNewEvents else {
            throw Failure.noDefaultCalendar
        }

        let event: EKEvent
        if let id = warranty.eventIdentifier, let existing = store.event(withIdentifier: id) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
        }

        event.title     = "Warranty expires: \(warranty.productName) (\(warranty.brand))"
        event.startDate = warranty.expiryDate
        event.endDate   = warranty.expiryDate
        event.isAllDay  = true
        event.calendar  = calendar
        event.alarms    = [EKAlarm(absoluteDate: nineAM(on: warranty.expiryDate))]

        var noteLines: [String] = []
        if !warranty.retailer.isEmpty     { noteLines.append("Retailer: \(warranty.retailer)") }
        if !warranty.serialNumber.isEmpty { noteLines.append("Serial: \(warranty.serialNumber)") }
        event.notes = noteLines.joined(separator: "\n")

        do {
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            throw Failure.underlying(error)
        }
    }

    /// Removes the event with the given identifier if it still exists.
    /// Silent no-op when the event has already been deleted manually.
    func deleteEvent(identifier: String) throws {
        guard let event = store.event(withIdentifier: identifier) else { return }
        do {
            try store.remove(event, span: .thisEvent)
        } catch {
            throw Failure.underlying(error)
        }
    }

    // MARK: - Helpers

    private func nineAM(on date: Date) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = 9
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? date
    }
}
