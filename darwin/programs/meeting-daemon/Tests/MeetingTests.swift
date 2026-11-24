import Foundation

func runMeetLinkTests() {
    let cases: [(name: String, texts: [String?], expected: URL?)] = [
        ("link alone in the URL field", ["https://meet.google.com/abc-defg-hij"], meetURL),
        ("link inside notes text", [nil, "Join with Google Meet: https://meet.google.com/abc-defg-hij?hs=122"], meetURL),
        ("upper-case code is lower-cased", ["meet.google.com/ABC-DEFG-HIJ"], meetURL),
        ("first field with a link wins", ["https://meet.google.com/abc-defg-hij", "meet.google.com/zzz-zzzz-zzz"], meetURL),
        ("code with an extra letter is not a Meet code", ["meet.google.com/abc-defg-hijk"], nil),
        ("no link anywhere", ["Room 4", nil], nil),
    ]
    for c in cases {
        test("extractMeetURL: \(c.name)") {
            let url = extractMeetURL(from: c.texts)

            expectEqual(url, c.expected)
        }
    }
}

func runMergeTests() {
    test("merge borrows the Meet link from the copy that has it") {
        let ownCalendarCopy = buildMeeting(title: "MEETING_TITLE", meetURL: nil, source: "OWN_CALENDAR")
        let sharedCalendarCopy = buildMeeting(title: "MEETING_TITLE", meetURL: meetURL, source: "SHARED_CALENDAR")

        let merged = mergeDuplicates([ownCalendarCopy, sharedCalendarCopy])

        expectEqual(merged, [buildMeeting(title: "MEETING_TITLE", meetURL: meetURL, source: "OWN_CALENDAR")])
    }

    test("merge matches titles case-insensitively") {
        let ownCalendarCopy = buildMeeting(title: "Standup", source: "OWN_CALENDAR")
        let sharedCalendarCopy = buildMeeting(title: "standup", source: "SHARED_CALENDAR")

        let merged = mergeDuplicates([ownCalendarCopy, sharedCalendarCopy])

        expectEqual(merged.map(\.source), ["OWN_CALENDAR"])
    }

    test("merge keeps occurrences at different times apart") {
        let first = buildMeeting(start: meetingStart, source: "FIRST")
        let second = buildMeeting(start: meetingStart + 3600, source: "SECOND")

        let merged = mergeDuplicates([first, second])

        expectEqual(merged.map(\.source), ["FIRST", "SECOND"])
    }

    test("merge marks the meeting attending when any copy is") {
        let colleagueView = buildMeeting(invitation: .notInvited)
        let ownView = buildMeeting(invitation: .attending)

        let merged = mergeDuplicates([colleagueView, ownView])

        expectEqual(merged.map(\.invitation), [.attending])
    }

    test("merge marks the meeting unanswered when your own copy is") {
        let colleagueView = buildMeeting(invitation: .notInvited)
        let ownView = buildMeeting(invitation: .unanswered)

        let merged = mergeDuplicates([colleagueView, ownView])

        expectEqual(merged.map(\.invitation), [.unanswered])
    }

    test("merge borrows the event id from the copy that has it") {
        let withoutID = buildMeeting(eventID: nil)
        let withID = buildMeeting(eventID: "EVENT_ID")

        let merged = mergeDuplicates([withoutID, withID])

        expectEqual(merged.map(\.eventID), ["EVENT_ID"])
    }
}

func runIsMeetingTests() {
    let cases: [(name: String, meeting: Meeting, expected: Bool)] = [
        ("attending without a link", buildMeeting(meetURL: nil, invitation: .attending), true),
        ("unanswered invite", buildMeeting(meetURL: nil, invitation: .unanswered), true),
        ("no attendees but a Meet link", buildMeeting(meetURL: meetURL, invitation: .noAttendees), true),
        ("no attendees and no link (a personal block)", buildMeeting(meetURL: nil, invitation: .noAttendees), false),
        ("declined, even with a link", buildMeeting(meetURL: meetURL, invitation: .declined), false),
        ("a colleague's meeting you're not in", buildMeeting(meetURL: meetURL, invitation: .notInvited), false),
    ]
    for c in cases {
        test("isMeeting: \(c.name)") {
            let result = isMeeting(c.meeting)

            expectEqual(result, c.expected)
        }
    }
}
