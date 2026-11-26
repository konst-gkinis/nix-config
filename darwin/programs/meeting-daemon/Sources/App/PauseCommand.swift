import Foundation

/// When `meeting-daemon stop <duration>` pauses until, in
/// `$XDG_STATE_HOME/meeting-daemon/paused-until` (default ~/.local/state).
/// Read on every tick, so pausing needs no daemon restart; `md start`
/// deletes it.
enum PauseFile {
    static var url: URL {
        let state = ProcessInfo.processInfo.environment["XDG_STATE_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/state")
        return state.appendingPathComponent("meeting-daemon/paused-until")
    }

    /// The end of the pause in force at `now`, if any.
    static func pausedUntil(now: Date = Date()) -> Date? {
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let until = parsePausedUntil(text), until > now else { return nil }
        return until
    }

    static func save(_ until: Date) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try formatPausedUntil(until).write(to: url, atomically: true, encoding: .utf8)
    }
}

/// `pause <duration>`: what `meeting-daemon stop 30m` runs.
func pauseCommand(_ args: [String]) -> Never {
    let text = args.dropFirst().joined(separator: " ")
    guard let duration = parsePauseDuration(text) else {
        fail("usage: stop [<N>m | <N>h], e.g. stop 21m or stop 7h")
    }
    let until = Date() + duration
    do { try PauseFile.save(until) } catch { fail("couldn't write \(PauseFile.url.path): \(error)") }
    print("Paused until \(inviteDay.string(from: until)): no alarms, Meet tabs, joining or invite popups (md start resumes).")
    exit(0)
}
