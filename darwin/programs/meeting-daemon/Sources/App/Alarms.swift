import Foundation

/// A critical alert with a looping sound that keeps going until you click a
/// button (or run `meeting-daemon silence`); `quiet` leaves the sound out.
/// One per meeting at a time.
/// Main-thread only.
final class Alarms {
    static let openButton = "Open meeting"

    private let soundPath = ProcessInfo.processInfo.environment["MEETING_DAEMON_SOUND"]
        ?? "/System/Library/Sounds/Sosumi.aiff"
    private var active: [String: (dialog: Process, sound: SoundLoop?)] = [:]

    var isRinging: Bool { !active.isEmpty }

    func ring(
        key: String, heading: String, detail: String, canOpen: Bool, quiet: Bool = false,
        onOpen: @escaping () -> Void
    ) {
        guard active[key] == nil else {
            log("alarm for \(key) is already ringing")
            return
        }
        let sound = quiet ? nil : SoundLoop(path: soundPath)
        let dialog = Process()
        dialog.executableURL = Bundle.main.executableURL
        dialog.arguments = ["alert", heading, detail, canOpen ? "1" : "0"]
        let output = Pipe(), errors = Pipe()
        dialog.standardOutput = output
        dialog.standardError = errors
        dialog.terminationHandler = { process in
            let answer = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let error = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            DispatchQueue.main.async { [self] in
                sound?.stop()
                active[key] = nil
                if process.terminationReason == .uncaughtSignal {
                    log("alarm \(key) silenced")
                } else if process.terminationStatus != 0 {
                    log("alarm dialog failed: \(error)")
                    notify(heading, detail)
                } else {
                    log("alarm \(key) dismissed with \"\(answer)\"")
                    if answer == Self.openButton { onOpen() }
                }
            }
        }
        do {
            try dialog.run()
        } catch {
            log("couldn't show the alarm dialog: \(error)")
            notify(heading, detail)
            return
        }
        sound?.start()
        active[key] = (dialog, sound)
        log("alarm \(quiet ? "showing silently" : "ringing"): \(heading) — \(detail)")
    }

    func silenceAll() {
        for (_, alarm) in active { alarm.dialog.terminate() }
    }
}

/// Plays a sound over and over on a background thread until stopped.
private final class SoundLoop {
    private let path: String
    private let lock = NSLock()
    private var stopped = false
    private var current: Process?

    init(path: String) { self.path = path }

    func start() {
        Thread.detachNewThread { [self] in
            while true {
                lock.lock()
                if stopped { lock.unlock(); return }
                let player = Process()
                player.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
                player.arguments = [path]
                do { try player.run() } catch { lock.unlock(); return }
                current = player
                lock.unlock()
                player.waitUntilExit()
                Thread.sleep(forTimeInterval: 0.3)
            }
        }
    }

    func stop() {
        lock.lock()
        stopped = true
        current?.terminate()
        lock.unlock()
    }
}
