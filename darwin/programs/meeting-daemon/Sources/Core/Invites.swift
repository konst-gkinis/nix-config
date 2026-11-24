import Foundation

/// An invite series as the mute list and the `mute`/`unmute` commands name it.
struct InviteRef: Equatable {
    var id: String
    var title: String
}

/// The invites to pop up about: unanswered, not muted, and one per series
/// (its next occurrence), soonest first.
func invitesToNag(_ meetings: [Meeting], muted: Set<String>) -> [Meeting] {
    var seen = Set<String>()
    return meetings.sorted { $0.start < $1.start }.filter {
        $0.invitation == .unanswered && !muted.contains($0.seriesID) && seen.insert($0.seriesID).inserted
    }
}

enum InvitePick: Equatable {
    case found(InviteRef)
    case noMatch
    case ambiguous([InviteRef])
}

/// Which invite `query` names: the one whose title equals it (ignoring case),
/// else the only one whose title contains it.
func pickInvite(_ query: String, from candidates: [InviteRef]) -> InvitePick {
    var seen = Set<String>()
    let unique = candidates.filter { seen.insert($0.id).inserted }
    let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
    let exact = unique.filter { $0.title.lowercased() == needle }
    let matches = exact.isEmpty ? unique.filter { $0.title.lowercased().contains(needle) } : exact
    switch matches.count {
    case 0: return .noMatch
    case 1: return .found(matches[0])
    default: return .ambiguous(matches)
    }
}

/// The mute list file: one `<series id>\t<title>` line per muted series.
func parseMuteList(_ text: String) -> [InviteRef] {
    text.split(separator: "\n").compactMap { line in
        let fields = line.split(separator: "\t", maxSplits: 1)
        guard let id = fields.first, !id.isEmpty else { return nil }
        return InviteRef(id: String(id), title: fields.count > 1 ? String(fields[1]) : "")
    }
}

func formatMuteList(_ refs: [InviteRef]) -> String {
    refs.map { "\($0.id)\t\($0.title.replacingOccurrences(of: "\n", with: " "))\n" }.joined()
}
