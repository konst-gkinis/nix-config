import Foundation

/// Calendar.app, the only source.
func makeSources() -> [MeetingSource] {
    var sources: [MeetingSource] = []
    let calendar = CalendarAppSource()
    if calendar.requestAccess() {
        sources.append(calendar)
        log("Calendar.app: reading \(calendar.calendarNames.count) calendar(s): \(calendar.calendarNames.joined(separator: ", "))")
    } else {
        log("Calendar.app: access denied — allow meeting-daemond in System Settings → Privacy & Security → Calendars")
    }
    return sources
}

/// Upcoming meetings from every source, merged and filtered.
func collectMeetings(_ sources: [MeetingSource], from: Date, to: Date) -> [Meeting] {
    var all: [Meeting] = []
    for source in sources {
        do { all += try source.meetings(from: from, to: to) } catch { log("\(source.name): \(error)") }
    }
    return mergeDuplicates(all).filter(isMeeting).sorted { $0.start < $1.start }
}

final class Daemon {
    private let sources: [MeetingSource]
    private var scheduler = Scheduler()
    private let alarms = Alarms()
    private let joiner = MeetJoiner(brave: Brave())
    /// Browser work blocks for up to a minute; it mustn't hold up polling or alarms.
    private let browserQueue = DispatchQueue(label: "browser")
    private var timer: Timer?
    private var inviteTimer: Timer?
    private var silenceSignal: DispatchSourceSignal?

    init(sources: [MeetingSource]) {
        self.sources = sources
    }

    func run() -> Never {
        log("meeting-daemon running (sources: \(sources.map(\.name).joined(separator: ", ")))")
        signal(SIGUSR1, SIG_IGN)
        silenceSignal = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        silenceSignal?.setEventHandler { [weak self] in
            log("silence requested")
            self?.alarms.silenceAll()
        }
        silenceSignal?.resume()

        let today = collectMeetings(sources, from: Date(), to: Date() + 12 * 3600)
        log("\(today.count) meeting(s) in the next 12 h" + today.map {
            "\n    \(timeOfDay.string(from: $0.start))  \($0.title)\($0.meetURL == nil ? "" : "  (Meet)")"
        }.joined())

        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.tick() }
        tick()
        inviteTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            self?.checkInvites()
        }
        checkInvites()
        RunLoop.main.run()
        exit(0)
    }

    private func tick() {
        let now = Date()
        let meetings = collectMeetings(
            sources,
            from: now - scheduler.leads.lateGrace - 60,
            to: now + scheduler.leads.horizon + 60
        )
        for action in scheduler.actions(for: meetings, now: now) { perform(action) }
    }

    private func perform(_ action: Action) {
        switch action {
        case .alarm(let meeting, let minutesLeft):
            // Already in the call (joined early): show the alarm without sound,
            // so it isn't heard by everyone else in it.
            browserQueue.async { [joiner] in
                let inCall = joiner.isInCall(meeting)
                DispatchQueue.main.async {
                    self.ringAlarm(
                        for: meeting,
                        heading: "\(meeting.title) in \(minutesLeft) min",
                        detail: "Starts at \(timeOfDay.string(from: meeting.start)).",
                        quiet: inCall
                    )
                }
            }

        case .openTab(let meeting):
            browserQueue.async { [joiner] in
                do {
                    let opened = try joiner.brave.focusOrOpen(meeting.meetURL!, focus: false)
                    log("\(meeting.title): Meet tab \(opened ? "opened" : "already open")")
                } catch {
                    log("\(meeting.title): couldn't open the Meet tab: \(error)")
                    notify("meeting-daemon", "Couldn't open the Meet tab: \(error)")
                }
            }

        case .ensureJoined(let meeting):
            browserQueue.async { [joiner] in
                let outcome = joiner.ensureJoined(meeting)
                DispatchQueue.main.async { self.report(outcome, for: meeting) }
            }
        }
    }

    private func report(_ outcome: JoinOutcome, for meeting: Meeting) {
        switch outcome {
        case .alreadyJoined:
            log("\(meeting.title): already in the call, mic/camera untouched")
        case .joined:
            log("\(meeting.title): joined with mic and camera off")
            notify(meeting.title, "Joined with mic and camera off.")
        case .askedToJoin:
            log("\(meeting.title): asked to join with mic and camera off")
            notify(meeting.title, "Asked to join (mic and camera off); waiting to be let in.")
        case .failed(let reason):
            log("\(meeting.title): couldn't join: \(reason)")
            ringAlarm(for: meeting, heading: "Join \(meeting.title) yourself", detail: "Couldn't join automatically: \(reason)")
        }
    }

    /// Pops up, silently, about invites you haven't answered yes, no or maybe.
    /// Again on every check until you answer or mute them; one still on
    /// screen from the last check isn't stacked.
    private func checkInvites() {
        let now = Date()
        let muted = Set(MuteList.load().map(\.id))
        let invites = invitesToNag(collectMeetings(sources, from: now, to: now + inviteHorizon), muted: muted)
        guard !invites.isEmpty else { return }
        let list = invites.map { "\($0.title)\n\(inviteDay.string(from: $0.start))" }.joined(separator: "\n\n")
        alarms.ring(
            key: "unanswered-invites",
            heading: invites.count == 1 ? "Answer this invite" : "Answer \(invites.count) invites",
            detail: list + "\n\nStop reminders about one with:\nmd mute <title>",
            openButton: "Open Calendar",
            dismissButton: "Later",
            quiet: true
        ) {
            runProcess("/usr/bin/open", ["-a", "Calendar"])
        }
    }

    private func ringAlarm(for meeting: Meeting, heading: String, detail: String, quiet: Bool = false) {
        alarms.ring(
            key: meeting.key, heading: heading, detail: detail,
            openButton: meeting.meetURL == nil ? nil : "Open meeting", quiet: quiet
        ) { [weak self] in
            self?.browserQueue.async {
                _ = try? self?.joiner.brave.focusOrOpen(meeting.meetURL!, focus: true)
            }
        }
    }
}
