import AppKit

/// `meeting-daemond alert <heading> <detail> <0|1>`: a critical, floating
/// NSAlert that prints the clicked button. Run as a child process by `Alarms`
/// (osascript's `display alert` doesn't show from a background process on
/// recent macOS), which also lets `silence` simply kill it.
func showAlert(heading: String, detail: String, canOpen: Bool) -> Never {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = heading
    alert.informativeText = detail
    alert.addButton(withTitle: "Stop")
    if canOpen { alert.addButton(withTitle: Alarms.openButton) }
    alert.window.level = .floating
    app.activate(ignoringOtherApps: true)
    let response = alert.runModal()
    print(response == .alertSecondButtonReturn ? Alarms.openButton : "Stop")
    exit(0)
}
