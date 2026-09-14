import XCTest

/// One test per Instagram story. Each writes `<test>.start` / `<test>.end` epoch marks so the
/// shell can trim the simulator recording. Labels come from the app's accessibility tree.
final class Stories: PromoCase {

    // MARK: helpers specific to the stories

    func openDisplayTank() {
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'DISPLAY TANK'")).firstMatch
        if card.waitForExistence(timeout: 5) { card.tap() }
    }

    /// A field that already has text loses its placeholder, so paired fields (ammonia/nitrite) are
    /// resolved by column: `index` 1 means the right-hand field of the row.
    func typeParam(_ placeholder: String, _ value: String, index: Int = 0) {
        let q = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", placeholder))
        XCTAssertTrue(q.firstMatch.waitForExistence(timeout: 5), "field \(placeholder)")
        var f = q.firstMatch
        if index == 1 {
            let all = q.allElementsBoundByIndex
            f = all.first(where: { $0.frame.minX > 150 }) ?? all.last ?? f
        }
        // SwiftUI's keyboard-avoidance scroll is not reflected in the accessibility frames until the
        // user scrolls explicitly, so nudge the content by hand (in the area above the keyboard and
        // the raised tab bar) before tapping; XCUITest then scrolls the field into view if needed.
        if app.keyboards.count > 0 {
            let from = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 201, dy: 360))
            let to = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 201, dy: 250))
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
            pause(1.0)
        }
        pause(0.3)
        if ProcessInfo.processInfo.environment["DEBUG_DUMPS"] != nil { dump("before-\(placeholder)-\(index)") }
        typeSlowly(f, value, delay: 0.10)
        pause(0.35)
    }

    /// Fills the full measurement form. `alk` etc. allow the story to pick its own numbers.
    func fillMeasurement(temp: String = "25.8", sal: String = "1.025", ph: String = "8.15", alk: String = "7.4",
                         ca: String = "400", mg: String = "1345", no3: String = "8", po4: String = "0.06",
                         nh3: String = "0", no2: String = "0") {
        typeParam("25.5", temp); typeParam("1.025", sal); typeParam("8.2", ph)
        typeParam("8.5", alk); typeParam("420", ca); typeParam("1350", mg)
        typeParam("5.0", no3); typeParam("0.03", po4); typeParam("0.0", nh3, index: 0); typeParam("0.0", no2, index: 1)
        hideKeyboard()
    }

    func hideKeyboard() {
        // Tapping the section header outside the fields ends editing in this form.
        let header = app.staticTexts["OBSERVATIONS"]
        if header.exists && header.isHittable { header.tap() } else { app.staticTexts["REEFBUDDY"].tap() }
        pause(0.4)
    }

    func scrollTo(_ el: XCUIElement, maxSwipes: Int = 6) {
        var n = 0
        while !(el.exists && el.isHittable) && n < maxSwipes { app.swipeUp(velocity: .slow); pause(0.4); n += 1 }
    }

    /// Refreshes stale accessibility frames after a keyboard-avoidance scroll (see typeParam).
    func nudgeIfKeyboard() {
        guard app.keyboards.count > 0 else { return }
        let from = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 201, dy: 340))
        let to = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 201, dy: 270))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
        pause(1.0)
    }

    func start() { mark("start"); launch(); pause(1.2) }
    func finish() { pause(1.5); mark("end") }

    // MARK: one-off setup: grant notification permission via the schedule editor

    func testSetupNotifications() {
        launch()
        tab("SETTINGS"); button("Maintenance Schedules, Local reminders on this device").tap(); pause(1)
        button("+ ADD SCHEDULE").tap(); pause(1)
        button("SAVE SCHEDULE").tap(); pause(1)
        let allow = app.buttons["ALLOW NOTIFICATIONS"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let ok = springboard.buttons["Allow"]
            if ok.waitForExistence(timeout: 5) { ok.tap() }
        }
        pause(1.5); dump("setup-after-save")
        // Remove the throwaway schedule (the newest one, first DELETE button in the list).
        let del = app.buttons["DELETE"].firstMatch
        if del.waitForExistence(timeout: 3) {
            del.tap()
            let confirm = app.alerts.buttons["DELETE"].firstMatch
            if confirm.waitForExistence(timeout: 3) { confirm.tap() }
        }
        pause(1); dump("setup-done")
    }

    // MARK: 1 · Log 10 parameters

    func testS01LogParameters() {
        start()
        openDisplayTank(); pause(0.8); dump("s01-after-card")
        tab("MEASURE"); pause(1.2); dump("s01-measure")
        fillMeasurement()
        scrollTo(app.buttons["ANALYZE PARAMETERS"]); pause(2.0)
        finish()
    }

    // MARK: 2 · Target hints and unit toggles

    func testS02TargetHints() {
        start()
        tab("MEASURE"); pause(1.0)
        typeParam("8.5", "7.2"); pause(1.5)
        typeParam("1350", "1350"); pause(1.0)
        typeParam("8.2", "8.3"); pause(1.0)
        app.swipeDown(velocity: .slow); pause(0.6)
        button("°F").tap(); pause(1.2)
        button("ppt").tap(); pause(1.2)
        button("SG").tap(); pause(0.6)
        button("°C").tap(); pause(1.0)
        finish()
    }

    // MARK: 3 · AI analysis (two cards)

    func testS03AIAnalysis() {
        start()
        tab("MEASURE"); pause(1.0)
        fillMeasurement()
        scrollTo(app.buttons["ANALYZE PARAMETERS"]); pause(1.0)
        button("ANALYZE PARAMETERS").tap()
        XCTAssertTrue(app.staticTexts["AI ANALYSIS"].waitForExistence(timeout: 90))
        pause(2.5); dump("s03-result")
        for _ in 0..<5 { app.swipeUp(velocity: .slow); pause(1.6) }
        let save = app.buttons["SAVE ANALYSIS"]
        if save.exists { save.tap(); pause(1.2); app.alerts.buttons["OK"].firstMatch.tap(); pause(0.6) }
        finish()
    }

    // MARK: 4 · Warnings first

    func testS04Warnings() {
        start()
        tab("MEASURE"); pause(1.0)
        fillMeasurement(temp: "26.1", sal: "1.024", ph: "7.9", alk: "6.8", ca: "380", mg: "1250", no3: "25", po4: "0.15", nh3: "0.5", no2: "0.25")
        scrollTo(app.buttons["ANALYZE PARAMETERS"]); pause(0.8)
        button("ANALYZE PARAMETERS").tap()
        XCTAssertTrue(app.staticTexts["AI ANALYSIS"].waitForExistence(timeout: 90))
        pause(2.0)
        app.swipeUp(velocity: .slow); pause(0.8)
        scrollTo(app.staticTexts["WARNINGS"], maxSwipes: 4); pause(3.0); dump("s04-warnings")
        app.swipeUp(velocity: .slow); pause(2.0)
        finish()
    }

    // MARK: 5 · Trend charts

    func testS05TrendCharts() {
        start()
        tab("HISTORY"); pause(1.5)
        button("90D").tap(); pause(1.0)
        button("ALK").tap(); pause(1.5)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'TREND CHART'")).firstMatch.tap(); pause(2.5)
        dump("s05-chart")
        // Tap along the chart to show the point details.
        let chart = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'chart' OR label CONTAINS 'chart'")).firstMatch
        if chart.exists { chart.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap(); pause(1.5) }
        button("CLOSE").tap(); pause(1.0)
        button("CA").tap(); pause(1.5)
        button("MG").tap(); pause(1.5)
        button("ALL").firstMatch.tap(); pause(1.0)   // date range ALL (first ALL button)
        button("ALK").tap(); pause(1.5)
        button("30D").tap(); pause(1.5)
        finish()
    }

    // MARK: 6 · History + CSV export

    func testS06Export() {
        start()
        tab("HISTORY"); pause(1.2)
        app.buttons["ALL"].firstMatch.tap(); pause(1.0)
        app.swipeUp(velocity: .slow); pause(0.8); app.swipeUp(velocity: .slow); pause(0.8)
        app.swipeDown(velocity: .fast); pause(0.4); app.swipeDown(velocity: .fast); pause(0.8)
        button("EXPORT").tap(); pause(1.5); dump("s06-export")
        button("90D").tap(); pause(1.2)
        app.swipeUp(velocity: .slow); pause(1.5)
        button("EXPORT CSV").tap(); pause(3.0); dump("s06-share")
        finish()
    }

    // MARK: 7 · Maintenance reminders

    func testS07Reminders() {
        start()
        tab("SETTINGS"); pause(0.8)
        button("Maintenance Schedules, Local reminders on this device").tap(); pause(2.0); dump("s07-list")
        button("+ ADD SCHEDULE").tap(); pause(1.5)
        _ = app.buttons["SAVE SCHEDULE"].waitForExistence(timeout: 5); dump("s07-editor")
        button("WATER CHANGE").tap(); pause(0.8)
        let picker = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Frag Tank'")).firstMatch
        if picker.exists { picker.tap(); pause(0.8); app.buttons["Display Tank"].firstMatch.tap(); pause(0.8) }
        button("EVERY N DAYS").tap(); pause(0.6)
        for _ in 0..<7 { app.buttons["plus"].firstMatch.tap(); pause(0.18) }   // 7 → 14 days
        pause(1.2)
        button("WEEKLY").tap(); pause(0.6)
        let mon = app.buttons["MON"].firstMatch; if mon.exists { mon.tap(); pause(0.4) }
        button("SUN").tap(); pause(1.0); dump("s07-editor2")
        app.swipeUp(velocity: .slow); pause(0.8)
        button("SAVE SCHEDULE").tap(); pause(2.0); dump("s07-saved")
        XCUIDevice.shared.press(.home); pause(1.0)
        mark("push")            // the shell sends a local notification banner now
        pause(2.5); dump("s07-banner"); pause(3.5)
        finish()
    }

    // MARK: 8 · Water change logging

    func testS08WaterChange() {
        start()
        tab("MEASURE"); pause(1.0)
        scrollTo(app.buttons["LOG WATER CHANGE"]); pause(0.8)
        button("LOG WATER CHANGE").tap(); pause(1.5); dump("s08-sheet")
        typeSlowly(field(placeholder: "10"), "20"); pause(0.6)
        nudgeIfKeyboard()
        typeSlowly(field(placeholder: "5"), "18"); pause(0.6)
        nudgeIfKeyboard()
        scrollTo(app.buttons["SAVE WATER CHANGE"]); pause(0.6)
        button("SAVE WATER CHANGE").tap(); pause(2.0)
        tab("HISTORY"); pause(2.0)
        finish()
    }

    // MARK: 9 · Livestock catalogue

    func testS09Livestock() {
        start()
        tab("LIVESTOCK"); pause(1.5)
        app.swipeUp(velocity: .slow); pause(1.0); app.swipeUp(velocity: .slow); pause(1.0)
        app.swipeDown(velocity: .fast); pause(0.3); app.swipeDown(velocity: .fast); pause(0.8)
        app.buttons["plus"].firstMatch.tap(); pause(1.5); dump("s09-add")
        app.swipeUp(velocity: .slow); pause(0.6)
        for c in ["SPS", "LPS", "SOFT CORAL", "FISH", "INVERTEBRATE", "ANEMONE"] {
            let b = app.buttons[c].firstMatch
            if b.exists { b.tap(); pause(0.45) }
        }
        pause(0.6)
        button("Cancel").tap(); pause(1.0)
        text("OCELLARIS CLOWNFISH").tap(); pause(2.5); dump("s09-detail")
        app.swipeUp(velocity: .slow); pause(1.8)
        app.swipeUp(velocity: .slow); pause(1.5)
        finish()
    }

    // MARK: 10 · Health log timeline

    func testS10HealthLog() {
        start()
        tab("LIVESTOCK"); pause(1.2)
        text("ACROPORA TENUIS").tap(); pause(2.0)
        scrollTo(app.buttons["LOG"]); pause(0.8)
        button("LOG").tap(); pause(1.5); dump("s10-logsheet")
        button("STRESSED").tap(); pause(1.0)
        let notes = app.textViews.firstMatch
        notes.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap(); pause(0.5)
        for ch in "Polyps retracted after light change" { app.typeText(String(ch)); pause(0.05) }
        pause(0.6)
        app.staticTexts["HEALTH STATUS"].firstMatch.tap(); pause(0.4)
        scrollTo(app.buttons["SAVE LOG"]); button("SAVE LOG").tap(); pause(2.0)
        app.swipeUp(velocity: .slow); pause(2.0); dump("s10-timeline1")
        button("Close").tap(); pause(1.0)
        scrollTo(app.staticTexts["MONTIPORA CAPITATA"]); text("MONTIPORA CAPITATA").tap(); pause(2.0)
        scrollTo(app.staticTexts["HEALTH LOG TIMELINE"]); pause(0.8)
        app.swipeUp(velocity: .slow); pause(3.0); dump("s10-timeline2")
        finish()
    }

    // MARK: 11 · Multiple tanks, 7 tank types

    func testS11Tanks() {
        start()
        pause(1.0)
        button("ADD NEW TANK").tap(); pause(1.5); dump("s11-add")
        typeSlowly(field(placeholder: "Enter tank name"), "Quarantine"); pause(0.5)
        typeSlowly(field(placeholder: "0"), "10"); pause(0.5)
        app.staticTexts["TANK TYPE"].tap(); pause(0.4)
        app.swipeUp(velocity: .slow); pause(0.8)
        for t in ["FISH ONLY", "FOWLR", "SOFT CORAL", "LPS", "SPS", "NANO", "FISH ONLY"] {
            let b = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", t)).firstMatch
            if b.exists && b.isHittable { b.tap(); pause(0.5) }
        }
        scrollTo(app.buttons["CREATE TANK"]); pause(0.6)
        button("CREATE TANK").tap(); pause(2.5); dump("s11-list")
        finish()
    }

    // MARK: 12 · Saved analyses

    func testS12SavedAnalyses() {
        start()
        tab("SETTINGS"); pause(0.8)
        button("Saved Analyses, 7 saved").tap(); pause(2.0); dump("s12-list")
        app.swipeUp(velocity: .slow); pause(1.2)
        app.swipeDown(velocity: .fast); pause(0.8)
        // Open the second-newest Display Tank analysis
        let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS 'DISPLAY TANK' OR label CONTAINS 'Display Tank'"))
        if rows.count > 1 { rows.element(boundBy: 1).tap() } else { rows.firstMatch.tap() }
        pause(2.0); dump("s12-detail")
        app.swipeUp(velocity: .slow); pause(1.8); app.swipeUp(velocity: .slow); pause(1.8)
        finish()
    }

    // MARK: 13 · Credits

    func testS13Credits() {
        start()
        tab("SETTINGS"); pause(0.8)
        button("Analysis Credits, Balance and credit packs").tap(); pause(3.0); dump("s13-credits")
        app.swipeUp(velocity: .slow); pause(2.0)
        finish()
    }

    // MARK: 14 · Design montage

    func testS14Montage() {
        start()
        pause(1.2)
        tab("MEASURE"); pause(1.4)
        tab("LIVESTOCK"); pause(1.4)
        tab("HISTORY"); pause(1.6)
        button("90D").tap(); button("ALK").tap(); pause(1.2)
        tab("SETTINGS"); pause(1.2)
        button("Saved Analyses, 7 saved").tap(); pause(1.6)
        button("Done").tap(); pause(0.6)
        tab("TANKS"); pause(1.5)
        finish()
    }
}
