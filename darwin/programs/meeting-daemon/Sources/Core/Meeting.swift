import Foundation

/// How the calendar owner relates to an event, as far as the source can tell.
enum Invitation: Equatable {
    /// You are an attendee (or the organiser) and haven't declined.
    case attending
    case declined
    /// You are an attendee and haven't answered yes, no or maybe yet.
    case unanswered
    /// The event has attendees but you aren't one: someone else's meeting on a
    /// calendar you can see (a colleague's shared calendar).
    case notInvited
    /// No attendee list at all: a personal block, or a solo event with a call link.
    case noAttendees
}

struct Meeting: Equatable {
    var title: String
    var start: Date
    var meetURL: URL?
    var invitation: Invitation
    /// Which source reported it ("Calendar.app", "cli"); for logs only.
    var source: String
    /// The calendar's own event id (iCalendar UID), shared by every occurrence
    /// of a recurring event and every calendar showing it. Nil when unknown.
    var eventID: String? = nil

    /// Identifies one occurrence across calendars and polls. Title rather than
    /// Meet code, because Calendar.app doesn't always expose the Meet link and
    /// the copies must still collapse into one.
    var key: String { "\(title.lowercased())|\(Int(start.timeIntervalSince1970))" }

    /// `abc-defg-hij` for a normalised Meet URL; what a browser tab's URL is matched on.
    var meetCode: String? { meetURL?.lastPathComponent }

    /// What muting an unanswered invite applies to: the whole series.
    var seriesID: String { eventID ?? key }
}

/// Collapses the copies of one occurrence that several calendars report (your
/// own and a colleague's shared one). The first copy wins, but it borrows a
/// Meet link, an event id and an `attending` from the others, and an
/// `unanswered` when it isn't your invite itself.
func mergeDuplicates(_ meetings: [Meeting]) -> [Meeting] {
    var byKey: [String: Meeting] = [:]
    var order: [String] = []
    for meeting in meetings {
        guard var existing = byKey[meeting.key] else {
            byKey[meeting.key] = meeting
            order.append(meeting.key)
            continue
        }
        if existing.meetURL == nil { existing.meetURL = meeting.meetURL }
        if existing.eventID == nil { existing.eventID = meeting.eventID }
        if meeting.invitation == .attending {
            existing.invitation = .attending
        } else if meeting.invitation == .unanswered, [.notInvited, .noAttendees].contains(existing.invitation) {
            existing.invitation = .unanswered
        }
        byKey[meeting.key] = existing
    }
    return order.compactMap { byKey[$0] }
}

/// Whether an event deserves an alarm: one you're attending, or an
/// attendee-less event that has a Meet link. Personal blocks (lunch, focus
/// time), declined invites and colleagues' meetings stay quiet.
func isMeeting(_ meeting: Meeting) -> Bool {
    switch meeting.invitation {
    case .attending, .unanswered: return true
    case .declined, .notInvited: return false
    case .noAttendees: return meeting.meetURL != nil
    }
}
