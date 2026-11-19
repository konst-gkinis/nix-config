import Foundation

// A minimal runner: nixpkgs' Swift ships neither an `xctest` runner nor a
// working swift-testing macro plugin, so the Core tests are a plain executable
// that exits non-zero on failure (run by the package's checkPhase).

private var failures: [String] = []
private var testCount = 0
private var currentTest = ""

func test(_ name: String, _ body: () throws -> Void) {
    testCount += 1
    currentTest = name
    let before = failures.count
    do { try body() } catch { failures.append("\(name): threw \(error)") }
    print(failures.count == before ? "  ok   \(name)" : "  FAIL \(name)")
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #fileID, line: UInt = #line) {
    guard actual != expected else { return }
    failures.append("\(currentTest) (\(file):\(line))\n    expected: \(expected)\n    actual:   \(actual)")
}

func finish() -> Never {
    for failure in failures { print("\nFAIL \(failure)") }
    print("\n\(testCount) tests, \(failures.count) failures")
    exit(failures.isEmpty ? 0 : 1)
}
