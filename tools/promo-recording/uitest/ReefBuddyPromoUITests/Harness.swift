import XCTest

/// Shared helpers for the promo recordings. OUT_DIR is passed via TEST_RUNNER_OUT_DIR.
class PromoCase: XCTestCase {
    var app: XCUIApplication!
    var outDir: String { ProcessInfo.processInfo.environment["OUT_DIR"] ?? "/tmp" }
    var backend: String { ProcessInfo.processInfo.environment["BACKEND"] ?? "http://localhost:8787" }

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication(bundleIdentifier: "au.com.aethers.reefbuddy")
        app.launchEnvironment["API_BASE_URL"] = backend
    }

    func launch() {
        app.launch()
        _ = app.staticTexts["REEFBUDDY"].waitForExistence(timeout: 15)
    }

    /// Epoch marks so the shell can trim the recording to the story.
    func mark(_ name: String) {
        let path = "\(outDir)/marks/\(self.name.split(separator: " ").last!.replacingOccurrences(of: "]", with: "")).\(name)"
        try? "\(Date().timeIntervalSince1970)".write(toFile: path, atomically: true, encoding: .utf8)
    }

    func dump(_ label: String) {
        try? app.debugDescription.write(toFile: "\(outDir)/marks/\(label).hierarchy.txt", atomically: true, encoding: .utf8)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(outDir)/marks/\(label).png"))
    }

    func pause(_ s: Double) { Thread.sleep(forTimeInterval: s) }

    func tab(_ title: String) { app.buttons[title].firstMatch.tap() }

    func text(_ t: String, timeout: Double = 8) -> XCUIElement {
        let e = app.staticTexts[t].firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "missing text \(t)")
        return e
    }

    func button(_ t: String, timeout: Double = 8) -> XCUIElement {
        let e = app.buttons[t].firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "missing button \(t)")
        return e
    }

    /// Slow, human-looking typing into a field.
    func typeSlowly(_ field: XCUIElement, _ value: String, delay: Double = 0.12) {
        field.tap(); pause(0.3)
        var tries = 0
        while app.keyboards.count == 0 && tries < 3 {
            pause(0.5)
            if app.keyboards.count == 0 { field.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap(); pause(0.4) }
            tries += 1
        }
        for ch in value { app.typeText(String(ch)); pause(delay) }
    }

    func field(placeholder: String) -> XCUIElement {
        let e = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", placeholder)).firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: 8), "missing field \(placeholder)")
        return e
    }

    func dismissKeyboard() {
        if app.keyboards.count > 0 {
            let done = app.toolbars.buttons["Done"]
            if done.exists { done.tap() } else { app.swipeDown() }
        }
    }

    func swipeUp(_ n: Int = 1, velocity: XCUIGestureVelocity = .slow) {
        for _ in 0..<n { app.swipeUp(velocity: velocity); pause(0.4) }
    }
}
