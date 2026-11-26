import Foundation

/// How long `md stop <duration>` pauses for: a number and a unit, minutes
/// ("30m", "45 min") or hours ("2h", "1.5 hours"). nil if it isn't one.
func parsePauseDuration(_ text: String) -> TimeInterval? {
    let text = text.trimmingCharacters(in: .whitespaces).lowercased()
    let number = text.prefix { $0.isNumber || $0 == "." }
    let unit = text.dropFirst(number.count).trimmingCharacters(in: .whitespaces)
    guard let value = Double(number), value > 0 else { return nil }
    switch unit {
    case "m", "min", "mins", "minute", "minutes": return value * 60
    case "h", "hr", "hrs", "hour", "hours": return value * 3600
    default: return nil
    }
}

/// The pause file holds the end of the pause as Unix seconds.
func formatPausedUntil(_ until: Date) -> String {
    "\(Int(until.timeIntervalSince1970))\n"
}

func parsePausedUntil(_ text: String) -> Date? {
    Int(text.trimmingCharacters(in: .whitespacesAndNewlines)).map { Date(timeIntervalSince1970: TimeInterval($0)) }
}
