import EventKit
import Foundation

protocol MeetingSource: AnyObject {
    var name: String { get }
    func meetings(from: Date, to: Date) throws -> [Meeting]
}

struct SourceError: Error, CustomStringConvertible {
    let description: String
}

/// Calendar.app's store via EventKit: local and iCloud calendars, and any
/// Google account added under System Settings → Internet Accounts.
final class CalendarAppSource: MeetingSource {
    let name = "Calendar.app"
    private let store = EKEventStore()

    /// Asks for Calendar access (macOS prompts once, naming meeting-daemon) and
    /// waits for the answer.
    func requestAccess() -> Bool {
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess { return true }
        var granted = false
        let answered = DispatchSemaphore(value: 0)
        store.requestFullAccessToEvents { ok, error in
            granted = ok
            if let error { log("Calendar access error: \(error.localizedDescription)") }
            answered.signal()
        }
        answered.wait()
        return granted
    }

    /// Calendar names it can read; empty when access isn't really there.
    var calendarNames: [String] { store.calendars(for: .event).map(\.title) }

    func meetings(from: Date, to: Date) throws -> [Meeting] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw SourceError(description: "no Calendar access (System Settings → Privacy & Security → Calendars)")
        }
        store.refreshSourcesIfNecessary()
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        return store.events(matching: predicate).compactMap { event in
            guard !event.isAllDay, event.status != .canceled else { return nil }
            return Meeting(
                title: event.title ?? "(no title)",
                start: event.startDate,
                meetURL: extractMeetURL(from: [event.url?.absoluteString, event.location, event.notes]),
                invitation: invitation(of: event),
                source: name
            )
        }
    }

    private func invitation(of event: EKEvent) -> Invitation {
        guard let attendees = event.attendees, !attendees.isEmpty else { return .noAttendees }
        if let me = attendees.first(where: \.isCurrentUser) {
            return me.participantStatus == .declined ? .declined : .attending
        }
        return event.organizer?.isCurrentUser == true ? .attending : .notInvited
    }
}
