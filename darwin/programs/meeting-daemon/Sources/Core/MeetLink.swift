import Foundation

private let meetPattern = try! NSRegularExpression(
    pattern: #"meet\.google\.com/([a-z]{3}-[a-z]{4}-[a-z]{3})\b"#,
    options: .caseInsensitive
)

/// The first Google Meet link in any of `texts` (URL field, location, notes),
/// normalised to `https://meet.google.com/<code>` with the query dropped.
func extractMeetURL(from texts: [String?]) -> URL? {
    for case let text? in texts {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = meetPattern.firstMatch(in: text, range: range),
              let codeRange = Range(match.range(at: 1), in: text)
        else { continue }
        return URL(string: "https://meet.google.com/\(text[codeRange].lowercased())")
    }
    return nil
}
