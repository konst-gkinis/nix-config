import Foundation

func runGoogleEventsTests() {
    test("reads title, start and Meet link of an accepted event") {
        let body = buildGoogleResponse([buildGoogleEvent(
            summary: "EVENT_SUMMARY",
            start: ["dateTime": "2026-11-19T10:00:00+01:00"],
            hangoutLink: "https://meet.google.com/abc-defg-hij"
        )])

        let meetings = try parseGoogleEvents(body, source: "SOURCE")

        expectEqual(meetings, [Meeting(
            title: "EVENT_SUMMARY",
            start: Date(timeIntervalSince1970: 1_795_078_800),
            meetURL: meetURL,
            invitation: .attending,
            source: "SOURCE"
        )])
    }

    test("takes the Meet link from conferenceData when hangoutLink is missing") {
        let body = buildGoogleResponse([buildGoogleEvent(
            hangoutLink: nil,
            conferenceData: ["entryPoints": [
                ["entryPointType": "phone", "uri": "tel:+1-555"],
                ["entryPointType": "video", "uri": "https://meet.google.com/abc-defg-hij"],
            ]]
        )])

        let meetings = try parseGoogleEvents(body)

        expectEqual(meetings.map(\.meetURL), [meetURL])
    }

    test("skips cancelled events") {
        let body = buildGoogleResponse([buildGoogleEvent(status: "cancelled")])

        let meetings = try parseGoogleEvents(body)

        expectEqual(meetings, [])
    }

    test("skips all-day events") {
        let body = buildGoogleResponse([buildGoogleEvent(start: ["date": "2026-11-19"])])

        let meetings = try parseGoogleEvents(body)

        expectEqual(meetings, [])
    }

    let invitationCases: [(name: String, attendees: [[String: Any]]?, organizer: [String: Any]?, expected: Invitation)] = [
        ("self declined", [["self": true, "responseStatus": "declined"]], nil, .declined),
        ("self tentative", [["self": true, "responseStatus": "tentative"]], nil, .attending),
        ("only other attendees", [["email": "OTHER_EMAIL", "responseStatus": "accepted"]], nil, .notInvited),
        ("organiser not in the attendee list", [["email": "OTHER_EMAIL"]], ["self": true], .attending),
        ("no attendee list", nil, nil, .noAttendees),
    ]
    for c in invitationCases {
        test("invitation: \(c.name)") {
            let body = buildGoogleResponse([buildGoogleEvent(attendees: c.attendees, organizer: c.organizer)])

            let meetings = try parseGoogleEvents(body)

            expectEqual(meetings.map(\.invitation), [c.expected])
        }
    }
}
