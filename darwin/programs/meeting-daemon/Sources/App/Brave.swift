import Foundation

enum BrowserError: Error, CustomStringConvertible {
    case javascriptDisabled
    case notAuthorised
    case noTab
    case script(String)

    var description: String {
        switch self {
        case .javascriptDisabled:
            "Brave blocks JavaScript from Apple Events (View → Developer → Allow JavaScript from Apple Events; build-switch sets it while Brave is closed)"
        case .notAuthorised:
            "meeting-daemon may not control Brave (System Settings → Privacy & Security → Automation)"
        case .noTab:
            "the Meet tab is gone"
        case .script(let message):
            message
        }
    }
}

/// Brave through its (Chromium) AppleScript dictionary: tabs are found by the
/// Meet code in their URL.
struct Brave {
    static let app = "Brave Browser"

    private static let focusOrOpenScript = """
        on run argv
          set theURL to item 1 of argv
          set theCode to item 2 of argv
          set shouldFocus to (item 3 of argv) is "1"
          tell application "\(app)"
            set found to false
            repeat with w in windows
              set i to 0
              repeat with t in tabs of w
                set i to i + 1
                if (URL of t) contains theCode then
                  set found to true
                  if shouldFocus then
                    set active tab index of w to i
                    set index of w to 1
                  end if
                  exit repeat
                end if
              end repeat
              if found then exit repeat
            end repeat
            if not found then
              if (count of windows) is 0 then
                make new window
                set URL of active tab of window 1 to theURL
              else
                make new tab at end of tabs of window 1 with properties {URL:theURL}
              end if
            end if
            if shouldFocus then activate
          end tell
          if found then return "found"
          return "opened"
        end run
        """

    private static let javascriptScript = """
        on run argv
          set theCode to item 1 of argv
          set js to item 2 of argv
          tell application "\(app)"
            repeat with w in windows
              repeat with t in tabs of w
                if (URL of t) contains theCode then return (execute t javascript js)
              end repeat
            end repeat
          end tell
          return "__NO_TAB__"
        end run
        """

    /// Makes sure a tab for `url` exists, opening one if not. `focus` also
    /// brings it (and Brave) to the front. Returns true when it had to open one.
    @discardableResult
    func focusOrOpen(_ url: URL, focus: Bool) throws -> Bool {
        let result = appleScript(Self.focusOrOpenScript, [url.absoluteString, url.lastPathComponent, focus ? "1" : "0"])
        guard result.ok else { throw classify(result.err) }
        return result.out == "opened"
    }

    func javascript(inTabWith code: String, _ js: String) throws -> String {
        let result = appleScript(Self.javascriptScript, [code, js])
        guard result.ok else { throw classify(result.err) }
        if result.out == "__NO_TAB__" { throw BrowserError.noTab }
        return result.out
    }

    private func classify(_ error: String) -> BrowserError {
        if error.contains("turned off") || error.contains("Allow JavaScript") { return .javascriptDisabled }
        if error.contains("-1743") || error.contains("Not authorized") { return .notAuthorised }
        return .script(error)
    }
}

enum JoinOutcome {
    case alreadyJoined
    case joined
    /// Clicked "Ask to join"; someone has to let you in.
    case askedToJoin
    case failed(String)
}

/// Gets you into a Meet call with mic and camera off, unless you're already in.
struct MeetJoiner {
    let brave: Brave

    func ensureJoined(_ meeting: Meeting) -> JoinOutcome {
        guard let url = meeting.meetURL, let code = meeting.meetCode else { return .failed("no Meet link") }
        do {
            if let status = try? status(code), status.joined { return .alreadyJoined }
            try brave.focusOrOpen(url, focus: true)

            let deadline = Date() + 45
            var muteAttempts = 0
            while Date() < deadline {
                guard let status = try statusOrNilWithoutTab(code) else {
                    Thread.sleep(forTimeInterval: 1)
                    continue
                }
                switch nextJoinStep(status) {
                case .alreadyJoined:
                    return .joined
                case .waitForPage:
                    Thread.sleep(forTimeInterval: 1)
                case .turnOff(let mic, let cam):
                    muteAttempts += 1
                    if muteAttempts > 3 { return .failed("the microphone/camera wouldn't turn off") }
                    if mic { _ = try brave.javascript(inTabWith: code, MeetPage.turnOffScript(mic: true)) }
                    if cam { _ = try brave.javascript(inTabWith: code, MeetPage.turnOffScript(mic: false)) }
                    Thread.sleep(forTimeInterval: 1)
                case .clickJoin:
                    _ = try brave.javascript(inTabWith: code, MeetPage.clickJoinScript)
                    return waitUntilInCall(code)
                case .refuse(let reason):
                    return .failed(reason)
                }
            }
            return .failed("the Meet page never showed a join button")
        } catch {
            return .failed("\(error)")
        }
    }

    private func waitUntilInCall(_ code: String) -> JoinOutcome {
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 1)
            if let status = try? status(code), status.joined { return .joined }
        }
        return .askedToJoin
    }

    func status(_ code: String) throws -> MeetPageStatus {
        let json = try brave.javascript(inTabWith: code, MeetPage.statusScript)
        return try JSONDecoder().decode(MeetPageStatus.self, from: Data(json.utf8))
    }

    private func statusOrNilWithoutTab(_ code: String) throws -> MeetPageStatus? {
        do { return try status(code) } catch BrowserError.noTab { return nil }
    }
}
