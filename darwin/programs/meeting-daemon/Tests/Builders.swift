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

func buildMeetPageStatus(
    joined: Bool = false,
    canJoin: Bool = true,
    mic: String? = "off",
    cam: String? = "off"
) -> MeetPageStatus {
    MeetPageStatus(joined: joined, canJoin: canJoin, mic: mic, cam: cam)
}
