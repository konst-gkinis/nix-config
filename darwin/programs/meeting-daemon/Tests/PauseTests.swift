import Foundation

func runPauseTests() {
    let durationCases: [(name: String, text: String, expected: TimeInterval?)] = [
        ("minutes", "21m", 21 * 60),
        ("minutes, spelled out with a space", "45 min", 45 * 60),
        ("hours", "7h", 7 * 3600),
        ("fractional hours, any case", "1.5 Hours", 90 * 60),
        ("a bare number has no unit", "30", nil),
        ("an unknown unit", "3d", nil),
        ("zero", "0m", nil),
        ("no number", "m", nil),
    ]
    for c in durationCases {
        test("parsePauseDuration: \(c.name)") {
            let duration = parsePauseDuration(c.text)

            expectEqual(duration, c.expected)
        }
    }

    test("pause file reads back the time it wrote") {
        let until = Date(timeIntervalSince1970: 1_800_000_000)

        let parsed = parsePausedUntil(formatPausedUntil(until))

        expectEqual(parsed, until)
    }

    test("an unreadable pause file means not paused") {
        let text = "PAUSED_UNTIL_GARBAGE"

        let parsed = parsePausedUntil(text)

        expectEqual(parsed, nil)
    }
}
