import Foundation

/// The start time every scheduler test measures against.
let meetingStart = Date(timeIntervalSince1970: 1_800_000_000)

let meetURL = URL(string: "https://meet.google.com/abc-defg-hij")!

func buildMeeting(
    title: String = "MEETING_TITLE",
    start: Date = meetingStart,
    meetURL: URL? = URL(string: "https://meet.google.com/aaa-bbbb-ccc"),
    invitation: Invitation = .attending,
    source: String = "SOURCE"
) -> Meeting {
    Meeting(title: title, start: start, meetURL: meetURL, invitation: invitation, source: source)
}

/// One event of a Google `events.list` response, as JSON.
func buildGoogleEvent(
    summary: String = "EVENT_SUMMARY",
    status: String = "confirmed",
    start: [String: Any] = ["dateTime": "2026-11-19T10:00:00+01:00"],
    hangoutLink: String? = nil,
    conferenceData: [String: Any]? = nil,
    attendees: [[String: Any]]? = [["email": "SELF_EMAIL", "self": true, "responseStatus": "accepted"]],
    organizer: [String: Any]? = nil
) -> [String: Any] {
    var event: [String: Any] = ["summary": summary, "status": status, "start": start]
    event["hangoutLink"] = hangoutLink
    event["conferenceData"] = conferenceData
    event["attendees"] = attendees
    event["organizer"] = organizer
    return event
}

func buildGoogleResponse(_ events: [[String: Any]]) -> Data {
    try! JSONSerialization.data(withJSONObject: ["items": events])
}

func buildMeetPageStatus(
    joined: Bool = false,
    canJoin: Bool = true,
    mic: String? = "off",
    cam: String? = "off"
) -> MeetPageStatus {
    MeetPageStatus(joined: joined, canJoin: canJoin, mic: mic, cam: cam)
}
