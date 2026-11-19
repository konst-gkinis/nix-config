import Foundation

struct ProcessResult {
    let status: Int32
    let out: String
    let err: String
    var ok: Bool { status == 0 }
}

@discardableResult
func runProcess(_ path: String, _ args: [String], stdin: String? = nil) -> ProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = args
    let outPipe = Pipe(), errPipe = Pipe(), inPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = errPipe
    if stdin != nil { process.standardInput = inPipe }
    do { try process.run() } catch {
        return ProcessResult(status: -1, out: "", err: "\(error)")
    }
    if let stdin {
        inPipe.fileHandleForWriting.write(Data(stdin.utf8))
        try? inPipe.fileHandleForWriting.close()
    }
    // Drain stderr on another thread so a chatty child can't fill one pipe and block.
    var errData = Data()
    let drained = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
        errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        drained.signal()
    }
    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
    drained.wait()
    process.waitUntilExit()
    let trim = { (d: Data) in String(decoding: d, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
    return ProcessResult(status: process.terminationStatus, out: trim(outData), err: trim(errData))
}

/// Runs AppleScript `source` (which should have an `on run argv` handler) with
/// `args` passed as argv, so nothing needs quoting into the script text.
@discardableResult
func appleScript(_ source: String, _ args: [String] = []) -> ProcessResult {
    runProcess("/usr/bin/osascript", ["-"] + args, stdin: source)
}

private let logTime: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f
}()

func log(_ message: String) {
    print("\(logTime.string(from: Date())) \(message)")
}

func notify(_ title: String, _ message: String) {
    appleScript("""
        on run argv
          display notification (item 2 of argv) with title (item 1 of argv)
        end run
        """, [title, message])
}

let timeOfDay: DateFormatter = {
    let f = DateFormatter()
    f.timeStyle = .short
    return f
}()
