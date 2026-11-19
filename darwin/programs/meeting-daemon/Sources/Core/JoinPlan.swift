import Foundation

/// What `MeetPage.statusScript` reports about a Meet tab.
struct MeetPageStatus: Decodable, Equatable {
    /// The in-call "Leave call" button is present.
    var joined: Bool
    /// A "Join now" / "Ask to join" button is present (the pre-join screen).
    var canJoin: Bool
    /// "on", "off", or nil when the toggle wasn't found.
    var mic: String?
    var cam: String?
}

enum JoinStep: Equatable {
    case alreadyJoined
    case waitForPage
    case turnOff(mic: Bool, cam: Bool)
    case clickJoin
    /// Joining isn't safe (we can't see the mic/camera state); leave it to you.
    case refuse(String)
}

/// The next step towards being in the call with mic and camera off. Joining
/// only ever happens from a status that shows both toggles off.
func nextJoinStep(_ status: MeetPageStatus) -> JoinStep {
    if status.joined { return .alreadyJoined }
    if !status.canJoin { return .waitForPage }
    guard let mic = status.mic, let cam = status.cam else {
        return .refuse("couldn't find the microphone/camera toggles")
    }
    if mic == "on" || cam == "on" { return .turnOff(mic: mic == "on", cam: cam == "on") }
    return .clickJoin
}

/// JavaScript run inside the Meet tab. English-UI labels: Meet in another
/// language won't match and the daemon falls back to an alarm.
enum MeetPage {
    private static let helpers = """
        const all = s => Array.from(document.querySelectorAll(s));
        const label = e => (e.getAttribute('aria-label') || '') + ' ' + (e.getAttribute('data-tooltip') || '');
        const toggle = re => all('[data-is-muted]').find(e => re.test(label(e)));
        const joinButton = () => all('button, [role="button"]')
          .find(e => /^(join now|ask to join|join anyway)$/i.test((e.innerText || '').trim()));
        """

    static let statusScript = """
        (function () {
          \(helpers)
          const state = e => e ? (e.getAttribute('data-is-muted') === 'true' ? 'off' : 'on') : null;
          return JSON.stringify({
            joined: all('[aria-label^="Leave call"], button[jsname="CQylAd"]').length > 0,
            canJoin: !!joinButton(),
            mic: state(toggle(/microphone/i)),
            cam: state(toggle(/camera/i)),
          });
        })()
        """

    static func turnOffScript(mic: Bool) -> String {
        """
        (function () {
          \(helpers)
          const t = toggle(\(mic ? "/microphone/i" : "/camera/i"));
          if (t && t.getAttribute('data-is-muted') === 'false') { t.click(); return 'clicked'; }
          return 'noop';
        })()
        """
    }

    static let clickJoinScript = """
        (function () {
          \(helpers)
          const b = joinButton();
          if (b) { b.click(); return 'clicked'; }
          return 'missing';
        })()
        """
}
