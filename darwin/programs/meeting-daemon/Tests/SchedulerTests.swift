import Foundation

func runSchedulerTests() {
    test("stays quiet more than 10 minutes before the meeting") {
        var scheduler = Scheduler()
        let meeting = buildMeeting(start: meetingStart)

        let actions = scheduler.actions(for: [meeting], now: meetingStart - 601)

        expectEqual(actions, [])
    }

    test("rings the alarm 10 minutes before the meeting") {
        var scheduler = Scheduler()
        let meeting = buildMeeting(start: meetingStart)

        let actions = scheduler.actions(for: [meeting], now: meetingStart - 600)

        expectEqual(actions, [.alarm(meeting, minutesLeft: 10)])
    }

    test("does not ring the same alarm again on the next poll") {
        var scheduler = Scheduler()
        let meeting = buildMeeting(start: meetingStart)
        _ = scheduler.actions(for: [meeting], now: meetingStart - 600)

        let actions = scheduler.actions(for: [meeting], now: meetingStart - 585)

        expectEqual(actions, [])
    }

    test("rings again 5 minutes before the meeting") {
        var scheduler = Scheduler()
        let meeting = buildMeeting(start: meetingStart)
        _ = scheduler.actions(for: [meeting], now: meetingStart - 600)

        let actions = scheduler.actions(for: [meeting], now: meetingStart - 300)

        expectEqual(actions, [.alarm(meeting, minutesLeft: 5)])
    }

    test("rings once, not twice, when first seeing a meeting under 5 minutes away") {
        var scheduler = Scheduler()
        let meeting = buildMeeting(start: meetingStart, meetURL: nil)

        let actions = scheduler.actions(for: [meeting], now: meetingStart - 230)

        expectEqual(actions, [.alarm(meeting, minutesLeft: 4)])
    }

    test("opens the Meet tab 2 minutes before the meeting") {
        var scheduler = Scheduler()
        let meeting = buildMeeting(start: meetingStart, meetURL: meetURL)
        _ = scheduler.actions(for: [meeting], now: meetingStart - 300)

        let actions = scheduler.actions(for: [meeting], now: meetingStart - 120)

        expectEqual(actions, [.openTab(meeting)])
    }

    test("joins 1 minute before the meeting") {
        var scheduler = Scheduler()
        let meeting = buildMeeting(start: meetingStart, meetURL: meetURL)
        _ = scheduler.actions(for: [meeting], now: meetingStart - 120)

        let actions = scheduler.actions(for: [meeting], now: meetingStart - 60)

        expectEqual(actions, [.ensureJoined(meeting)])
    }

    test("opens no tab for a meeting without a Meet link") {
        var scheduler = Scheduler()
        let meeting = buildMeeting(start: meetingStart, meetURL: nil)
        _ = scheduler.actions(for: [meeting], now: meetingStart - 300)

        let actions = scheduler.actions(for: [meeting], now: meetingStart - 60)

        expectEqual(actions, [])
    }

    test("still opens and joins a meeting that started under 5 minutes ago") {
        var scheduler = Scheduler()
        let meeting = buildMeeting(start: meetingStart, meetURL: meetURL)

        let actions = scheduler.actions(for: [meeting], now: meetingStart + 240)

        expectEqual(actions, [.openTab(meeting), .ensureJoined(meeting)])
    }

    test("ignores a meeting that started more than 5 minutes ago") {
        var scheduler = Scheduler()
        let meeting = buildMeeting(start: meetingStart, meetURL: meetURL)

        let actions = scheduler.actions(for: [meeting], now: meetingStart + 301)

        expectEqual(actions, [])
    }

    test("treats a rescheduled meeting as a new occurrence") {
        var scheduler = Scheduler()
        let original = buildMeeting(start: meetingStart, meetURL: nil)
        let moved = buildMeeting(start: meetingStart + 60, meetURL: nil)
        _ = scheduler.actions(for: [original], now: meetingStart - 600)

        let actions = scheduler.actions(for: [moved], now: meetingStart - 540)

        expectEqual(actions, [.alarm(moved, minutesLeft: 10)])
    }
}
