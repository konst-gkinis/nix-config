import Foundation

func runInviteTests() {
    test("nags about an unanswered invite") {
        let invite = buildMeeting(invitation: .unanswered, eventID: "EVENT_ID")

        let nag = invitesToNag([invite], muted: [])

        expectEqual(nag, [invite])
    }

    test("does not nag about an answered meeting") {
        let answered = buildMeeting(invitation: .attending, eventID: "EVENT_ID")

        let nag = invitesToNag([answered], muted: [])

        expectEqual(nag, [])
    }

    test("does not nag about a muted series") {
        let invite = buildMeeting(invitation: .unanswered, eventID: "MUTED_EVENT_ID")

        let nag = invitesToNag([invite], muted: ["MUTED_EVENT_ID"])

        expectEqual(nag, [])
    }

    test("nags once per recurring series, about its next occurrence") {
        let later = buildMeeting(start: meetingStart + 7 * 86400, invitation: .unanswered, eventID: "SERIES_ID")
        let next = buildMeeting(start: meetingStart, invitation: .unanswered, eventID: "SERIES_ID")

        let nag = invitesToNag([later, next], muted: [])

        expectEqual(nag, [next])
    }

    test("an invite without an event id is muted by its occurrence key") {
        let invite = buildMeeting(title: "MEETING_TITLE", start: meetingStart, invitation: .unanswered, eventID: nil)

        let nag = invitesToNag([invite], muted: ["meeting_title|1800000000"])

        expectEqual(nag, [])
    }

    let weekly = buildInviteRef(id: "WEEKLY_ID", title: "Weekly sync")
    let weeklyReview = buildInviteRef(id: "REVIEW_ID", title: "Weekly sync review")
    let planning = buildInviteRef(id: "PLANNING_ID", title: "Planning")
    let pickCases: [(name: String, query: String, candidates: [InviteRef], expected: InvitePick)] = [
        ("unique substring, any case", "plan", [weekly, planning], .found(planning)),
        ("exact title beats a longer one containing it", "weekly SYNC", [weekly, weeklyReview], .found(weekly)),
        ("several titles contain it", "weekly", [weekly, weeklyReview], .ambiguous([weekly, weeklyReview])),
        ("two occurrences of one series count once", "plan", [planning, planning], .found(planning)),
        ("nothing contains it", "retro", [weekly, planning], .noMatch),
    ]
    for c in pickCases {
        test("pickInvite: \(c.name)") {
            let pick = pickInvite(c.query, from: c.candidates)

            expectEqual(pick, c.expected)
        }
    }

    test("mute list reads back what it wrote") {
        let refs = [buildInviteRef(id: "FIRST_ID", title: "FIRST_TITLE"), buildInviteRef(id: "SECOND_ID", title: "SECOND_TITLE")]

        let parsed = parseMuteList(formatMuteList(refs))

        expectEqual(parsed, refs)
    }

    test("mute list skips blank lines") {
        let text = "EVENT_ID\tMEETING_TITLE\n\n"

        let parsed = parseMuteList(text)

        expectEqual(parsed, [buildInviteRef(id: "EVENT_ID", title: "MEETING_TITLE")])
    }
}
