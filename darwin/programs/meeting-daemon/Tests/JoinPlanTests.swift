import Foundation

func runJoinPlanTests() {
    let cases: [(name: String, status: MeetPageStatus, expected: JoinStep)] = [
        ("already in the call", buildMeetPageStatus(joined: true, canJoin: false, mic: "on", cam: "on"), .alreadyJoined),
        ("page still loading", buildMeetPageStatus(canJoin: false), .waitForPage),
        ("mic on", buildMeetPageStatus(canJoin: true, mic: "on", cam: "off"), .turnOff(mic: true, cam: false)),
        ("camera on", buildMeetPageStatus(canJoin: true, mic: "off", cam: "on"), .turnOff(mic: false, cam: true)),
        ("both off", buildMeetPageStatus(canJoin: true, mic: "off", cam: "off"), .clickJoin),
        ("mic toggle missing", buildMeetPageStatus(canJoin: true, mic: nil, cam: "off"),
         .refuse("couldn't find the microphone/camera toggles")),
    ]
    for c in cases {
        test("nextJoinStep: \(c.name)") {
            let step = nextJoinStep(c.status)

            expectEqual(step, c.expected)
        }
    }
}
