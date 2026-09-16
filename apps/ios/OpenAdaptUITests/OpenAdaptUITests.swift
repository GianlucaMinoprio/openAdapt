import XCTest

final class OpenAdaptUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor func testAddTieShortcutOpensAppleConfirmation() throws {
        let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
        shortcuts.terminate()
        let app = XCUIApplication(); app.launchArguments = ["--demo"]; app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        let setup = app.buttons["siri-voice-setup"]
        for _ in 0..<4 {
            if setup.isHittable { break }
            app.swipeUp()
        }
        setup.tap()
        guard app.buttons["add-tie-shortcut"].waitForExistence(timeout: 3) else {
            throw XCTSkip("Generate the bundle-specific Siri shortcut files before this integration test.")
        }
        app.buttons["add-tie-shortcut"].tap()
        let add = shortcuts.buttons["Add Shortcut"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        XCTAssertTrue(shortcuts.staticTexts["Tie my shoes"].firstMatch.exists)
        capture(shortcuts, name: "add-tie-shortcut")
        // Preview the signed workflow without running it or creating duplicates
        // on repeated tests. The native editor must resolve our action summary.
        shortcuts.buttons["More"].firstMatch.tap()
        let action = shortcuts.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] 'Tie my shoes using my last saved fit'")
        ).firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        capture(shortcuts, name: "tie-shortcut-action")
    }
    @MainActor func testIndependentFitLinkedFitAndSheets() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["DEMO · NO SHOES CONNECTED"].waitForExistence(timeout: 5))
        let left = app.otherElements["left-fit"]
        XCTAssertTrue(left.waitForExistence(timeout: 3))
        let start = left.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.65))
        start.press(forDuration: 0.1, thenDragTo: left.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.3)))
        XCTAssertNotEqual(left.value as? String, "30 percent")
        XCTAssertEqual(app.otherElements["right-fit"].value as? String, "30 percent")
        let idle = NSPredicate(format: "value CONTAINS 'percent' AND NOT value CONTAINS 'lacing'")
        expectation(for: idle, evaluatedWith: left)
        waitForExpectations(timeout: 5)
        capture(app, name: "fit")
        app.buttons["Link"].tap()
        let right = app.otherElements["right-fit"]
        right.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).press(forDuration: 0.1,
            thenDragTo: right.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        expectation(for: idle, evaluatedWith: right)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(left.value as? String, right.value as? String)
        capture(app, name: "linked-fit")
        app.buttons["Battery"].tap()
        XCTAssertTrue(app.staticTexts["Ready when you are."].waitForExistence(timeout: 3))
        capture(app, name: "battery")
        app.buttons["Done"].tap()
        app.buttons["Lights"].tap()
        XCTAssertTrue(app.buttons["Volt"].waitForExistence(timeout: 3))
        capture(app, name: "lights")
        XCTAssertTrue(app.staticTexts["Make them yours."].exists)
        app.buttons["Blue"].tap()
        app.buttons["Done"].tap()
        expectation(for: NSPredicate(format: "value == 'Blue'"), evaluatedWith: app.buttons["Lights"])
        waitForExpectations(timeout: 3)
        capture(app, name: "fit-blue")
        app.buttons["Lights"].tap()
        app.buttons["Indigo"].tap()
        app.buttons["Done"].tap()
        expectation(for: NSPredicate(format: "value == 'Indigo'"), evaluatedWith: app.buttons["Lights"])
        waitForExpectations(timeout: 3)
        capture(app, name: "fit-indigo")
        app.buttons["Lights"].tap()
        app.buttons["Lights off"].tap()
        app.buttons["Done"].tap()
        expectation(for: NSPredicate(format: "value == 'Off'"), evaluatedWith: app.buttons["Lights"])
        waitForExpectations(timeout: 3)
        capture(app, name: "fit-lights-off")
        app.buttons["Lights"].tap()
        app.buttons["Volt"].tap()
        app.buttons["Done"].tap()
        expectation(for: NSPredicate(format: "value == 'Volt'"), evaluatedWith: app.buttons["Lights"])
        waitForExpectations(timeout: 3)
        app.buttons["Modes"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Chill'")).firstMatch.waitForExistence(timeout: 3))
        capture(app, name: "modes")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Chill'")).firstMatch.tap()
        app.buttons["Done"].tap()
        expectation(for: NSPredicate(format: "value == '30 percent'"), evaluatedWith: left)
        waitForExpectations(timeout: 5)
    }
    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testWelcomeAndGuidedSetup() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-onboarding"]; app.launch()
        XCTAssertTrue(app.buttons["connect-shoes"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        capture(app, name: "welcome")
        app.buttons["connect-shoes"].tap()
        XCTAssertTrue(app.buttons["add-shoes"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["import-pairing"].exists)
        capture(app, name: "my-shoes")
        app.buttons["add-shoes"].tap()
        XCTAssertTrue(app.buttons["find-shoes"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["New pairing is coming"].exists)
        capture(app, name: "guided-setup")
        app.swipeUp()
        app.buttons["Connected to an old app?"].tap()
        app.buttons["About factory reset"].tap()
        XCTAssertTrue(app.staticTexts["Before you reset"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'can’t yet set up a reset pair'")).firstMatch.exists)
        capture(app, name: "reset-guide")
    }
    @MainActor func testConnectingDisablesFitAndCanCancel() {
        let app = XCUIApplication(); app.launchArguments = ["--demo-connecting"]; app.launch()
        XCTAssertTrue(app.staticTexts["Connecting"].waitForExistence(timeout: 3))
        let left = app.otherElements["left-fit"]
        XCTAssertEqual(left.value as? String, "Not connected")
        left.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).press(forDuration: 0.1,
            thenDragTo: left.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        XCTAssertEqual(left.value as? String, "Not connected")
        XCTAssertFalse(app.buttons["Lights"].exists)
        capture(app, name: "connecting")
        app.buttons["connection-action"].tap()
        XCTAssertTrue(app.staticTexts["Not connected"].waitForExistence(timeout: 3))
        capture(app, name: "disconnected")
    }
    @MainActor func testReducedMotionFitStillWorks() {
        let app = XCUIApplication(); app.launchArguments = ["--demo", "--reduce-motion"]; app.launch()
        let left = app.otherElements["left-fit"]
        XCTAssertTrue(left.waitForExistence(timeout: 3))
        left.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).press(forDuration: 0.1,
            thenDragTo: left.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        XCTAssertNotEqual(left.value as? String, "30 percent")
        expectation(for: NSPredicate(format: "value CONTAINS 'percent' AND NOT value CONTAINS 'lacing'"), evaluatedWith: left)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(app.otherElements["right-fit"].value as? String, "30 percent")
    }
    @MainActor func testConnectShowsTheActualBluetoothFailureAndCanRetry() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-bluetooth-off"]; app.launch()
        XCTAssertTrue(app.staticTexts["Not connected"].waitForExistence(timeout: 5))
        for _ in 0..<2 {
            app.buttons["connection-action"].tap()
            XCTAssertTrue(app.staticTexts["Couldn’t connect"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.staticTexts["Turn on Bluetooth to connect your shoes."].exists)
            XCTAssertFalse(app.staticTexts["Your shoes are asleep"].exists)
            XCTAssertEqual(app.otherElements["left-fit"].value as? String, "Not connected")
            XCTAssertFalse(app.buttons["Lights"].exists)
        }
        capture(app, name: "connection-error")
    }
    @MainActor func testSiriSetupIsDiscoverableInSettings() {
        let app = XCUIApplication(); app.launchArguments = ["--demo"]; app.launch()
        XCTAssertTrue(app.buttons["Modes"].waitForExistence(timeout: 5))
        app.buttons["Modes"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Chill'")).firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Chill' AND label CONTAINS 'Used by Tie Shoes'")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        let shortcuts = app.buttons["siri-shortcuts-link"]
        for _ in 0..<4 {
            if shortcuts.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(shortcuts.isHittable)
        let help = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Connect each shoe here once first'")).firstMatch
        if !help.exists { app.swipeUp() }
        XCTAssertTrue(help.waitForExistence(timeout: 3))
        capture(app, name: "siri-shortcuts")
        let setup = app.buttons["siri-voice-setup"]
        if !setup.isHittable { app.swipeDown() }
        setup.tap()
        XCTAssertTrue(app.staticTexts["Siri, tie my shoes with OpenAdapt"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Siri, untie my shoes with OpenAdapt"].exists)
        let rememberedFit = app.descendants(matching: .any).matching(identifier: "siri-remembered-fit").firstMatch
        if !rememberedFit.exists { app.swipeUp() }
        XCTAssertEqual(rememberedFit.label, "Chill")
        XCTAssertEqual(rememberedFit.value as? String, "Left 30 percent, right 30 percent")
        capture(app, name: "siri-voice-setup")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Add “Untie my shoes”"].waitForExistence(timeout: 3))
        capture(app, name: "siri-voice-steps")
    }
    @MainActor func testTieShoesDefaultsToFirstSavedFit() {
        let app = XCUIApplication(); app.launchArguments = ["--demo"]; app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        let setup = app.buttons["siri-voice-setup"]
        for _ in 0..<4 {
            if setup.isHittable { break }
            app.swipeUp()
        }
        setup.tap()
        let fit = app.descendants(matching: .any).matching(identifier: "siri-remembered-fit").firstMatch
        if !fit.exists { app.swipeUp() }
        XCTAssertTrue(fit.waitForExistence(timeout: 3))
        XCTAssertEqual(fit.label, "Move")
        XCTAssertEqual(fit.value as? String, "Left 60 percent, right 60 percent")
        XCTAssertTrue(app.staticTexts["Starts with your first saved fit. Apply another mode whenever you want to change it."].exists)
        capture(app, name: "siri-default-fit")
    }
}
