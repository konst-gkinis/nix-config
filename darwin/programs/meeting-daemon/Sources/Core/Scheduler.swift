import Foundation

enum Action: Equatable {
    case alarm(Meeting, minutesLeft: Int)
    case openTab(Meeting)
    case ensureJoined(Meeting)
}

/// Seconds before a meeting's start at which each action becomes due.
struct Leads {
    var alarms: [TimeInterval] = [10 * 60, 5 * 60]
    var openTab: TimeInterval = 2 * 60
    var join: TimeInterval = 60
    /// How long after the start the tab/join actions are still taken, so a
    /// Mac waking up just after the start still gets you into the call.
    /// Alarms stop at the start.
    var lateGrace: TimeInterval = 5 * 60

    /// How far ahead sources need to look.
    var horizon: TimeInterval { (alarms + [openTab, join]).max() ?? 0 }
}

/// Decides, poll by poll, what is due. Each action fires at most once per
/// meeting occurrence, and a poll that finds several alarm leads already
/// passed (the daemon just started, the Mac just woke) rings only once.
struct Scheduler {
    var leads = Leads()
    private var fired = Set<String>()

    mutating func actions(for meetings: [Meeting], now: Date) -> [Action] {
        var actions: [Action] = []
        for meeting in meetings.sorted(by: { $0.start < $1.start }) {
            let left = meeting.start.timeIntervalSince(now)

            let dueAlarms = leads.alarms
                .filter { left > 0 && left <= $0 }
                .map { "\(meeting.key)#alarm\(Int($0))" }
            if dueAlarms.contains(where: { !fired.contains($0) }) {
                fired.formUnion(dueAlarms)
                actions.append(.alarm(meeting, minutesLeft: Int((left / 60).rounded(.up))))
            }

            guard meeting.meetURL != nil, left > -leads.lateGrace else { continue }
            if left <= leads.openTab, fired.insert("\(meeting.key)#tab").inserted {
                actions.append(.openTab(meeting))
            }
            if left <= leads.join, fired.insert("\(meeting.key)#join").inserted {
                actions.append(.ensureJoined(meeting))
            }
        }
        return actions
    }
}
