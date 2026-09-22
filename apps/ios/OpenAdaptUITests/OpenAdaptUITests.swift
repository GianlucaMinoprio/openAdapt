import XCTest

final class OpenAdaptUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor func testDeveloperPairingExportOpensNativeSaveWithoutChangingPair() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-bluetooth-off"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        let developer = app.buttons["developer-shoes"]
        for _ in 0..<5 {
            if developer.isHittable { break }
            app.swipeUp()
        }
        developer.tap()
        let export = app.buttons["export-pairing"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        capture(app, name: "developer-pairing-export")
        export.tap()
        XCTAssertTrue(app.buttons["DOCPicker.actionButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["DOCPicker.filenameTextField"].exists)
        capture(app, name: "pairing-export-save")
        // The iOS 27 document sheet has a drag handle in place of Cancel.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.09)).press(forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: export)
        waitForExpectations(timeout: 5)
    }
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
    @MainActor func testIndependentFitAndSheets() throws {
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
        XCTAssertFalse(app.buttons["Link"].exists)
        let leftValue = left.value as? String
        let right = app.otherElements["right-fit"]
        right.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).press(forDuration: 0.1,
            thenDragTo: right.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        expectation(for: idle, evaluatedWith: right)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(left.value as? String, leftValue)
        XCTAssertNotEqual(right.value as? String, "30 percent")
        capture(app, name: "fit-three-buttons")
        app.buttons["Lights"].press(forDuration: 0.1, thenDragTo: app.buttons["Battery"])
        XCTAssertTrue(app.staticTexts["Ready when you are."].waitForExistence(timeout: 3))
        capture(app, name: "battery")
        app.buttons["Done"].tap()
        app.buttons["Battery"].press(forDuration: 0.1, thenDragTo: app.buttons["Lights"])
        XCTAssertTrue(app.buttons["Volt"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.segmentedControls.count, 0)
        capture(app, name: "lights-pair")
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
        app.buttons["Lights"].press(forDuration: 0.1, thenDragTo: app.buttons["Modes"])
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
    @MainActor func testShoeDetailsNicknameAppearanceAutoLaceAndRemoval() {
        let app = XCUIApplication(); app.launchArguments = ["--demo"]; app.launch()
        XCTAssertTrue(app.buttons["My shoes"].waitForExistence(timeout: 5))
        app.buttons["My shoes"].tap()
        let card = app.buttons["shoe-card-demo-pair"]
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts.matching(identifier: "Nike Adapt Auto Max").count, 1)
        capture(app, name: "shoes-cards")
        card.tap()
        XCTAssertTrue(app.buttons["shoe-nickname"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Calibrate Fit"].exists)
        capture(app, name: "shoe-connected-details")
        app.buttons["shoe-nickname"].tap()
        let nickname = app.textFields["nickname-field"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 3)); nickname.tap()
        nickname.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (nickname.value as? String)?.count ?? 0))
        nickname.typeText("Daily pair")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Daily pair"].waitForExistence(timeout: 3))
        app.buttons["shoe-color"].tap()
        app.buttons["colorway-blackTeal"].tap()
        capture(app, name: "shoe-colorways")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let colorRow = app.buttons["shoe-color"]
        XCTAssertTrue((colorRow.label + (colorRow.value as? String ?? "")).contains("Black / Teal"))
        app.buttons["shoe-auto-lace"].tap()
        XCTAssertEqual(app.segmentedControls.count, 0)
        let autoLace = app.switches["feature-autoLace-toggle"].firstMatch
        XCTAssertTrue(autoLace.waitForExistence(timeout: 3))
        expectation(for: NSPredicate(format: "value == '0' AND enabled == true"), evaluatedWith: autoLace)
        waitForExpectations(timeout: 3)
        autoLace.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "value == '1' AND enabled == true"), evaluatedWith: autoLace)
        waitForExpectations(timeout: 3)
        capture(app, name: "auto-lace-simple")
        autoLace.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "value == '0' AND enabled == true"), evaluatedWith: autoLace)
        waitForExpectations(timeout: 3)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.swipeUp()
        app.buttons["Disconnect shoes"].tap()
        XCTAssertTrue(app.buttons["guided-connect"].waitForExistence(timeout: 3))
        capture(app, name: "shoe-disconnected-details")
        app.buttons["remove-shoes"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
        capture(app, name: "remove-shoe-confirmation")
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["guided-connect"].exists)
        app.buttons["remove-shoes"].tap()
        app.alerts.buttons.matching(identifier: "confirm-remove-shoes").firstMatch.tap()
        XCTAssertTrue(app.buttons["add-shoes"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["shoe-card-demo-pair"].exists)
    }
    @MainActor func testQuickUnlacePairToggleAndReadback() {
        let app = XCUIApplication(); app.launchArguments = ["--demo"]; app.launch()
        XCTAssertTrue(app.buttons["My shoes"].waitForExistence(timeout: 5))
        app.buttons["My shoes"].tap()
        app.buttons["shoe-card-demo-pair"].tap()
        app.buttons["shoe-gestures"].tap()
        XCTAssertTrue(app.navigationBars["Quick Unlace"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.segmentedControls.count, 0)
        let quickUnlace = app.switches["feature-doubleTapUntie-toggle"].firstMatch
        XCTAssertTrue(quickUnlace.waitForExistence(timeout: 3))
        expectation(for: NSPredicate(format: "value == '0' AND enabled == true"), evaluatedWith: quickUnlace)
        waitForExpectations(timeout: 3)
        quickUnlace.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "value == '1' AND enabled == true"), evaluatedWith: quickUnlace)
        waitForExpectations(timeout: 3)
        capture(app, name: "quick-unlace-simple")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["shoe-gestures"].tap()
        expectation(for: NSPredicate(format: "value == '1' AND enabled == true"), evaluatedWith: quickUnlace)
        waitForExpectations(timeout: 3)
        quickUnlace.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "value == '0' AND enabled == true"), evaluatedWith: quickUnlace)
        waitForExpectations(timeout: 3)
        XCTAssertFalse(app.buttons["refresh-gesture-setting"].exists)
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
        XCTAssertTrue(app.staticTexts["Start with either shoe."].exists)
        capture(app, name: "guided-setup")
        app.swipeUp()
        app.buttons["Connected to an old app?"].tap()
        app.buttons["About factory reset"].tap()
        XCTAssertTrue(app.staticTexts["Before you reset"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'removes the old pairing'")).firstMatch.exists)
        capture(app, name: "reset-guide")
    }
    @MainActor func testEnrollmentShowsOnlyTheFirstShoeInstruction() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-onboarding", "--ui-found-shoes", "--ui-enrollment"]
        app.launch()
        app.buttons["connect-shoes"].tap(); app.buttons["add-shoes"].tap()
        capture(app, name: "new-shoes-intro")
        app.buttons["find-shoes"].tap()
        XCTAssertTrue(app.staticTexts["Press a light on your shoe."].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["pairing-step"].label, "SHOE 1 OF 2")
        XCTAssertFalse(app.staticTexts["Now your right shoe."].exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "first-shoe-paired").firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Firmware'")).firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'discovered-shoe-'")).firstMatch.exists)
        capture(app, name: "new-shoes-first-confirmation")
        app.buttons["cancel-pairing"].tap()
        XCTAssertTrue(app.buttons["add-shoes"].waitForExistence(timeout: 3))
    }
    @MainActor func testFirstLeftShoeLeadsToRightShoeInstruction() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-onboarding", "--ui-found-shoes", "--ui-enrollment-second"]
        app.launch()
        app.buttons["connect-shoes"].tap(); app.buttons["add-shoes"].tap()
        app.buttons["find-shoes"].tap()
        XCTAssertTrue(app.staticTexts["Now your right shoe."].waitForExistence(timeout: 9))
        XCTAssertTrue(app.staticTexts["Press either illuminated button on your right shoe to finish pairing."].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["pairing-step"].label, "SHOE 2 OF 2")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "first-shoe-paired").firstMatch.label.contains("Left shoe paired"))
        XCTAssertFalse(app.staticTexts["Your shoes are paired."].exists)
        capture(app, name: "new-shoes-second-confirmation")
    }
    @MainActor func testFirstRightShoeLeadsToLeftShoeWithReducedMotion() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-onboarding", "--ui-found-shoes", "--ui-enrollment-second", "--ui-right-first", "--reduce-motion"]
        app.launch()
        app.buttons["connect-shoes"].tap(); app.buttons["add-shoes"].tap()
        app.buttons["find-shoes"].tap()
        XCTAssertTrue(app.staticTexts["Now your left shoe."].waitForExistence(timeout: 9))
        XCTAssertTrue(app.staticTexts["Press either illuminated button on your left shoe to finish pairing."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "first-shoe-paired").firstMatch.label.contains("Right shoe paired"))
        XCTAssertFalse(app.staticTexts["Your shoes are paired."].exists)
        capture(app, name: "new-shoes-left-confirmation-reduced-motion")
    }
    @MainActor func testFailedFirstShoeDoesNotAdvanceToPartner() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-onboarding", "--ui-found-shoes", "--ui-enrollment-fail-first"]
        app.launch()
        app.buttons["connect-shoes"].tap(); app.buttons["add-shoes"].tap()
        app.buttons["find-shoes"].tap()
        XCTAssertTrue(app.staticTexts["Let’s try that again."].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["pairing-step"].label, "SHOE 1 OF 2")
        XCTAssertFalse(app.staticTexts["Now your right shoe."].exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "first-shoe-paired").firstMatch.exists)
        XCTAssertTrue(app.buttons["find-shoes"].isEnabled)
    }
    @MainActor func testPairingInstructionsRemainAccessibleWithLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-onboarding", "--ui-found-shoes", "--ui-enrollment-second", "--reduce-motion",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["connect-shoes"].tap(); app.buttons["add-shoes"].tap()
        for _ in 0..<4 where !app.buttons["find-shoes"].isHittable { app.swipeUp() }
        app.buttons["find-shoes"].tap()
        XCTAssertTrue(app.staticTexts["Now your right shoe."].waitForExistence(timeout: 9))
        let instruction = app.staticTexts["Press either illuminated button on your right shoe to finish pairing."]
        XCTAssertTrue(instruction.waitForExistence(timeout: 3))
        XCTAssertTrue(instruction.isHittable)
        capture(app, name: "new-shoes-large-text")
    }
    @MainActor func testVerifiedEnrollmentAddsTheNativePair() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-onboarding", "--ui-found-shoes", "--ui-enrollment-complete"]
        app.launch()
        app.buttons["connect-shoes"].tap(); app.buttons["add-shoes"].tap()
        app.buttons["find-shoes"].tap()
        XCTAssertTrue(app.staticTexts["Your shoes are paired."].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["pairing-step"].label, "PAIR COMPLETE")
        capture(app, name: "new-shoes-saved")
        app.buttons["find-shoes"].tap()
        XCTAssertTrue(app.staticTexts["Nike Adapt Auto Max"].waitForExistence(timeout: 4))
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
        let app = XCUIApplication(); app.launchArguments = ["--ui-bluetooth-off", "--ui-multiple-pairs"]; app.launch()
        XCTAssertTrue(app.staticTexts["Not connected"].waitForExistence(timeout: 5))
        for _ in 0..<2 {
            app.buttons["connection-action"].tap()
            XCTAssertTrue(app.staticTexts["Couldn’t connect"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.staticTexts["Turn on Bluetooth to connect your shoes."].exists)
            XCTAssertFalse(app.staticTexts["Your shoes are asleep"].exists)
            XCTAssertEqual(app.otherElements["left-fit"].value as? String, "Not connected")
            XCTAssertFalse(app.buttons["Lights"].exists)
        }
        XCTAssertTrue(app.staticTexts["Choose another pair in My shoes."].exists)
        capture(app, name: "connection-error")
        app.buttons["My shoes"].tap()
        XCTAssertTrue(app.buttons["shoe-card-connection-test"].waitForExistence(timeout: 3))
        app.buttons["shoe-card-other-test"].tap()
        let connect = app.buttons["guided-connect"]
        XCTAssertTrue(connect.waitForExistence(timeout: 3))
        XCTAssertTrue(connect.isEnabled)
        connect.tap()
        XCTAssertTrue(app.staticTexts["Turn on Bluetooth to connect your shoes."].waitForExistence(timeout: 3))
        app.buttons["BackButton"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["WEEKEND SHOES"].waitForExistence(timeout: 3))
        capture(app, name: "other-pair-selected")
    }
    @MainActor func testSiriSetupIsDiscoverableInSettings() {
        let app = XCUIApplication(); app.launchArguments = ["--demo"]; app.launch()
        XCTAssertTrue(app.buttons["Modes"].waitForExistence(timeout: 5))
        app.buttons["Modes"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Chill'")).firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Chill' AND label CONTAINS 'Used by Tie Shoes'")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        capture(app, name: "fit-glass")
        app.buttons["Settings"].tap()
        XCTAssertFalse(app.switches["Haptic feedback"].exists)
        XCTAssertFalse(app.staticTexts["Control steps"].exists)
        XCTAssertTrue(app.buttons["developer-shoes"].exists)
        capture(app, name: "settings-clean")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "repository-link").firstMatch.exists)
        app.buttons["developer-shoes"].tap()
        XCTAssertTrue(app.staticTexts["Tested firmware"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["check-new-shoe"].exists)
        capture(app, name: "developer-shoes")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["siri-voice-setup"].tap()
        XCTAssertTrue(app.buttons["siri-help"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Built-in phrases"].exists)
        capture(app, name: "siri-simple")
        app.buttons["siri-help"].tap()
        let rememberedFit = app.descendants(matching: .any).matching(identifier: "siri-remembered-fit").firstMatch
        XCTAssertTrue(rememberedFit.waitForExistence(timeout: 3))
        XCTAssertEqual(rememberedFit.label, "Chill")
        XCTAssertEqual(rememberedFit.value as? String, "Left 30 percent, right 30 percent")
        capture(app, name: "siri-help")
        app.swipeUp()
        XCTAssertTrue(app.buttons["siri-shortcuts-link"].exists)
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
        app.buttons["siri-help"].tap()
        let fit = app.descendants(matching: .any).matching(identifier: "siri-remembered-fit").firstMatch
        if !fit.exists { app.swipeUp() }
        XCTAssertTrue(fit.waitForExistence(timeout: 3))
        XCTAssertEqual(fit.label, "Move")
        XCTAssertEqual(fit.value as? String, "Left 60 percent, right 60 percent")
        XCTAssertTrue(app.staticTexts["Your last applied mode, or your first saved fit to start. Untying keeps it remembered."].exists)
        capture(app, name: "siri-default-fit")
    }
}
