import Foundation

/// How far ahead unanswered invites are looked for.
let inviteHorizon: TimeInterval = 14 * 86400

/// The series `meeting-daemon mute` silenced, in
/// `$XDG_STATE_HOME/meeting-daemon/muted-invites` (default ~/.local/state).
/// Read on every check, so muting needs no daemon restart.
enum MuteList {
    static var url: URL {
        let state = ProcessInfo.processInfo.environment["XDG_STATE_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/state")
        return state.appendingPathComponent("meeting-daemon/muted-invites")
    }

    static func load() -> [InviteRef] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parseMuteList(text)
    }

    static func save(_ refs: [InviteRef]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try formatMuteList(refs).write(to: url, atomically: true, encoding: .utf8)
    }
}

/// Every unanswered invite (muted or not) in the next `inviteHorizon`.
func unansweredInvites(_ sources: [MeetingSource], now: Date = Date()) -> [Meeting] {
    invitesToNag(collectMeetings(sources, from: now, to: now + inviteHorizon), muted: [])
}

let inviteDay: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEE d MMM HH:mm"
    return f
}()

/// The `unanswered`, `mute` and `unmute` commands.
func inviteCommand(_ args: [String]) -> Never {
    let sources = makeSources()
    let muted = MuteList.load()
    let query = args.dropFirst().joined(separator: " ")
    switch args.first {
    case "unanswered":
        let mutedIDs = Set(muted.map(\.id))
        let invites = unansweredInvites(sources)
        if invites.isEmpty { print("No unanswered invites in the next \(Int(inviteHorizon / 86400)) days.") }
        for invite in invites {
            print("\(inviteDay.string(from: invite.start))  \(invite.title)\(mutedIDs.contains(invite.seriesID) ? "  (muted)" : "")")
        }

    case "mute":
        guard !query.isEmpty else { fail("usage: mute <meeting title>") }
        let candidates = unansweredInvites(sources).map { InviteRef(id: $0.seriesID, title: $0.title) }
        let ref = picked(query, from: candidates, what: "unanswered invite")
        if muted.contains(where: { $0.id == ref.id }) {
            print("Already muted: \(ref.title)")
        } else {
            save(muted + [ref])
            print("No more reminders about \(ref.title) (meeting-daemon unmute brings them back).")
        }

    case "unmute":
        guard !query.isEmpty else { fail("usage: unmute <meeting title>") }
        let ref = picked(query, from: muted, what: "muted invite")
        save(muted.filter { $0.id != ref.id })
        print("Reminding you about \(ref.title) again from the next check (every 5 min).")

    default:
        fail("unknown invite command")
    }
    exit(0)
}

private func picked(_ query: String, from candidates: [InviteRef], what: String) -> InviteRef {
    switch pickInvite(query, from: candidates) {
    case .found(let ref):
        return ref
    case .noMatch:
        fail("no \(what) matches \"\(query)\"")
    case .ambiguous(let refs):
        fail("\"\(query)\" matches several; be more specific:\n" + refs.map { "  \($0.title)" }.joined(separator: "\n"))
    }
}

private func save(_ refs: [InviteRef]) {
    do { try MuteList.save(refs) } catch { fail("couldn't write \(MuteList.url.path): \(error)") }
}
