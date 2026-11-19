import Foundation

/// The subset of a Google Calendar API `events.list` response we read.
private struct EventList: Decodable {
    var items: [Event]?

    struct Event: Decodable {
        var status: String?
        var summary: String?
        var start: When?
        var hangoutLink: String?
        var conferenceData: Conference?
        var attendees: [Person]?
        var organizer: Person?
        var location: String?
        var description: String?
    }

    struct When: Decodable {
        /// Absent for all-day events, which carry `date` instead.
        var dateTime: String?
    }

    struct Person: Decodable {
        var isSelf: Bool?
        var responseStatus: String?
        enum CodingKeys: String, CodingKey {
            case isSelf = "self"
            case responseStatus
        }
    }

    struct Conference: Decodable {
        var entryPoints: [EntryPoint]?
        struct EntryPoint: Decodable {
            var entryPointType: String?
            var uri: String?
        }
    }
}

/// Timed, non-cancelled events from an `events.list` response body.
func parseGoogleEvents(_ body: Data, source: String = "Google Calendar API") throws -> [Meeting] {
    let dates = ISO8601DateFormatter()
    return try JSONDecoder().decode(EventList.self, from: body).items?.compactMap { event in
        guard event.status != "cancelled",
              let dateTime = event.start?.dateTime,
              let start = dates.date(from: dateTime)
        else { return nil }

        let video = event.conferenceData?.entryPoints?.first { $0.entryPointType == "video" }?.uri
        return Meeting(
            title: event.summary ?? "(no title)",
            start: start,
            meetURL: extractMeetURL(from: [event.hangoutLink, video, event.location, event.description]),
            invitation: googleInvitation(attendees: event.attendees, organizer: event.organizer),
            source: source
        )
    } ?? []
}

private func googleInvitation(attendees: [EventList.Person]?, organizer: EventList.Person?) -> Invitation {
    guard let attendees, !attendees.isEmpty else { return .noAttendees }
    if let me = attendees.first(where: { $0.isSelf == true }) {
        return me.responseStatus == "declined" ? .declined : .attending
    }
    return organizer?.isSelf == true ? .attending : .notInvited
}
