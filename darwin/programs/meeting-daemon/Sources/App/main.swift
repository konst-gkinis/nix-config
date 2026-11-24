import Foundation

// meeting-daemond: the binary launchd runs (so macOS's Calendar and
// Automation permissions are granted to it, by name). The `meeting-daemon`
// shell wrapper handles launchd and passes the other subcommands through.

setvbuf(stdout, nil, _IOLBF, 0)

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("meeting-daemond: \(message)\n".utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())

switch args.first {
case "run":
    Daemon(sources: makeSources()).run()

case "upcoming":
    let hours = args.dropFirst().first.flatMap(Double.init) ?? 12
    let now = Date()
    let sources = makeSources()
    let meetings = collectMeetings(sources, from: now, to: now + hours * 3600)
    let day = DateFormatter()
    day.dateFormat = "EEE HH:mm"
    if meetings.isEmpty { print("No meetings in the next \(Int(hours)) h.") }
    for meeting in meetings {
        print("\(day.string(from: meeting.start))  \(meeting.title)  [\(meeting.source)]  \(meeting.meetURL?.absoluteString ?? "-")")
    }

case "test-alarm":
    let alarms = Alarms()
    alarms.ring(key: "test", heading: "Test meeting in 10 min", detail: "This is what a meeting alarm looks like.",
                openButton: nil) {}
    while alarms.isRinging { RunLoop.main.run(until: Date() + 0.2) }

case "join":
    guard let link = args.dropFirst().first, let url = extractMeetURL(from: [link]) else {
        fail("usage: join <meet link>")
    }
    let meeting = Meeting(title: url.lastPathComponent, start: Date(), meetURL: url, invitation: .attending, source: "cli")
    switch MeetJoiner(brave: Brave()).ensureJoined(meeting) {
    case .alreadyJoined: print("Already in the call; left mic/camera alone.")
    case .joined: print("Joined with mic and camera off.")
    case .askedToJoin: print("Asked to join with mic and camera off.")
    case .failed(let reason): fail(reason)
    }

case "meet-status":
    guard let link = args.dropFirst().first, let code = extractMeetURL(from: [link])?.lastPathComponent else {
        fail("usage: meet-status <meet link>")
    }
    do { print(try MeetJoiner(brave: Brave()).status(code)) } catch { fail("\(error)") }

case "unanswered", "mute", "unmute":
    inviteCommand(args)

case "alert":
    guard args.count == 4 || args.count == 5 else {
        fail("usage: alert <heading> <detail> <open button title, or empty> [dismiss button title]")
    }
    showAlert(heading: args[1], detail: args[2], openButton: args[3], dismissButton: args.count == 5 ? args[4] : "Stop")

default:
    fail("unknown command; see `meeting-daemon help`")
}
