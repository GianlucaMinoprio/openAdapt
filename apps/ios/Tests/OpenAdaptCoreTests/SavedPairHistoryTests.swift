import XCTest
@testable import OpenAdaptCore

final class SavedPairHistoryTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    override func setUp() {
        suite = "SavedPairHistoryTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }
    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    func testStartupUsesLatestCompleteConnectionAcrossAppRestarts() {
        let history = SavedPairHistory(defaults: defaults)
        history.recordConnectedPair("automax", confirmedSides: [.left, .right])
        history.recordConnectedPair("huarache", confirmedSides: [.left, .right])
        let reopened = SavedPairHistory(defaults: defaults)
        XCTAssertEqual(reopened.preferredPairID(among: ["automax", "huarache"]), "huarache")
        history.recordConnectedPair("automax", confirmedSides: [.left, .right])
        XCTAssertEqual(reopened.preferredPairID(among: ["huarache", "automax"]), "automax")
    }

    func testFailedOrPartialConnectionDoesNotReplaceDefault() {
        let history = SavedPairHistory(defaults: defaults)
        history.recordConnectedPair("automax", confirmedSides: [.left, .right])
        for sides: Set<ShoeSide> in [[], [.left], [.right]] {
            XCTAssertFalse(history.recordConnectedPair("other", confirmedSides: sides))
            XCTAssertEqual(history.preferredPairID(among: ["other", "automax"]), "automax")
        }
        // Even a stale legacy selection cannot override confirmed history.
        defaults.set("other", forKey: "selectedPair")
        XCTAssertEqual(history.preferredPairID(among: ["other", "automax"]), "automax")
    }

    func testRemovingMostRecentPairRestoresPreviousConnectedPair() {
        let history = SavedPairHistory(defaults: defaults)
        history.recordConnectedPair("older", confirmedSides: [.left, .right])
        history.recordConnectedPair("latest", confirmedSides: [.left, .right])
        history.removePair("latest")
        XCTAssertEqual(history.preferredPairID(among: ["never-connected", "older"]), "older")
        // Re-adding a removed pair does not restore its old priority.
        XCTAssertEqual(history.preferredPairID(among: ["latest", "older"]), "older")
    }

    func testMissingProfilesAreIgnoredAndEmptyLibraryHasNoDefault() {
        let history = SavedPairHistory(defaults: defaults)
        history.recordConnectedPair("older", confirmedSides: [.left, .right])
        history.recordConnectedPair("missing", confirmedSides: [.left, .right])
        XCTAssertEqual(history.preferredPairID(among: ["fresh", "older"]), "older")
        XCTAssertEqual(history.preferredPairID(among: ["fresh"]), "fresh")
        XCTAssertNil(history.preferredPairID(among: []))
    }

    func testUpgradePreservesPreviousSelectionUntilFirstSuccess() {
        let history = SavedPairHistory(defaults: defaults)
        XCTAssertEqual(history.preferredPairID(among: ["first", "previous"]), "first")
        defaults.set("previous", forKey: "selectedPair")
        XCTAssertEqual(history.preferredPairID(among: ["first", "previous"]), "previous")
        history.recordConnectedPair("first", confirmedSides: [.left, .right])
        XCTAssertEqual(history.preferredPairID(among: ["first", "previous"]), "first")
    }
}
