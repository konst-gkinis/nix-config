import AppKit

/// What `meeting-daemond alert` prints when the second button was clicked.
let alertOpenAnswer = "open"

/// `meeting-daemond alert <heading> <detail> <open button title> [dismiss title]`:
/// a critical, floating NSAlert with a dismiss button (default "Stop"), plus a
/// second button unless its title is empty. Prints `open` or `stop`. Run as a child process by `Alarms`
/// (osascript's `display alert` doesn't show from a background process on
/// recent macOS), which also lets `silence` simply kill it.
func showAlert(heading: String, detail: String, openButton: String, dismissButton: String) -> Never {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = heading
    alert.informativeText = detail
    alert.addButton(withTitle: dismissButton)
    if !openButton.isEmpty { alert.addButton(withTitle: openButton) }
    alert.window.level = .floating
    app.activate(ignoringOtherApps: true)
    let response = alert.runModal()
    print(response == .alertSecondButtonReturn ? alertOpenAnswer : "stop")
    exit(0)
}
