import Foundation

/// How the calendar owner relates to an event, as far as the source can tell.
enum Invitation: Equatable {
    /// You are an attendee (or the organiser) and haven't declined.
    case attending
    case declined
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
    /// Which source reported it ("Calendar.app", "Google Calendar API"); for logs only.
    var source: String

    /// Identifies one occurrence across sources and polls. Title rather than
    /// Meet code, because Calendar.app doesn't always expose the Meet link and
    /// the two copies must still collapse into one.
    var key: String { "\(title.lowercased())|\(Int(start.timeIntervalSince1970))" }

    /// `abc-defg-hij` for a normalised Meet URL; what a browser tab's URL is matched on.
    var meetCode: String? { meetURL?.lastPathComponent }
}

/// Collapses the copies of one occurrence that Calendar.app (with the Google
/// account synced into it) and the Google Calendar API both report. The first
/// copy wins, but it borrows a Meet link and an `attending` from the others.
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
        if meeting.invitation == .attending { existing.invitation = .attending }
        byKey[meeting.key] = existing
    }
    return order.compactMap { byKey[$0] }
}

/// Whether an event deserves an alarm: one you're attending, or an
/// attendee-less event that has a Meet link. Personal blocks (lunch, focus
/// time), declined invites and colleagues' meetings stay quiet.
func isMeeting(_ meeting: Meeting) -> Bool {
    switch meeting.invitation {
    case .attending: return true
    case .declined, .notInvited: return false
    case .noAttendees: return meeting.meetURL != nil
    }
}
