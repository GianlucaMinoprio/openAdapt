import XCTest
@testable import OpenAdaptCore

final class SavedFitHistoryTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private var history: SavedFitHistory!
    private let move = UUID()
    private let chill = UUID()

    override func setUp() {
        suite = "OpenAdapt.SavedFitHistoryTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        history = SavedFitHistory(defaults: defaults)
    }
    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    func testFirstUseHasNoConfirmedHistory() {
        XCTAssertNil(history.lastUsedMode(forPair: "pair-a", availableModes: [move, chill]))
    }

    func testConfirmedModeSurvivesStoreRecreation() {
        history.recordConfirmedMode(chill, forPair: "pair-a", confirmedSides: [.left, .right])
        let reopened = SavedFitHistory(defaults: UserDefaults(suiteName: suite)!)
        XCTAssertEqual(reopened.lastUsedMode(forPair: "pair-a", availableModes: [move, chill]), chill)
    }

    func testPartialOrFailedModeDoesNotReplaceLastConfirmedFit() {
        history.recordConfirmedMode(chill, forPair: "pair-a", confirmedSides: [.left, .right])
        for confirmed: Set<ShoeSide> in [[], [.left], [.right]] {
            XCTAssertFalse(history.recordConfirmedMode(move, forPair: "pair-a", confirmedSides: confirmed))
            XCTAssertEqual(history.lastUsedMode(forPair: "pair-a", availableModes: [move, chill]), chill)
        }
    }

    func testMostRecentConfirmedModeWins() {
        history.recordConfirmedMode(chill, forPair: "pair-a", confirmedSides: [.left, .right])
        history.recordConfirmedMode(move, forPair: "pair-a", confirmedSides: [.right, .left])
        XCTAssertEqual(history.lastUsedMode(forPair: "pair-a", availableModes: [move, chill]), move)
    }

    func testPairSwitchDoesNotReuseAnotherPairsFit() {
        history.recordConfirmedMode(chill, forPair: "pair-a", confirmedSides: [.left, .right])
        XCTAssertNil(history.lastUsedMode(forPair: "pair-b", availableModes: [move, chill]))
        history.recordConfirmedMode(move, forPair: "pair-b", confirmedSides: [.left, .right])
        XCTAssertEqual(history.lastUsedMode(forPair: "pair-a", availableModes: [move, chill]), chill)
        XCTAssertEqual(history.lastUsedMode(forPair: "pair-b", availableModes: [move, chill]), move)
    }

    func testDeletedModeDoesNotReturnStaleHistory() {
        history.recordConfirmedMode(chill, forPair: "pair-a", confirmedSides: [.left, .right])
        XCTAssertNil(history.lastUsedMode(forPair: "pair-a", availableModes: [move]))
    }

    func testRemovingPairClearsOnlyThatPairsHistory() {
        history.recordConfirmedMode(chill, forPair: "pair-a", confirmedSides: [.left, .right])
        history.recordConfirmedMode(move, forPair: "pair-b", confirmedSides: [.left, .right])
        history.clear(forPair: "pair-a")
        XCTAssertNil(history.lastUsedMode(forPair: "pair-a", availableModes: [move, chill]))
        XCTAssertEqual(history.lastUsedMode(forPair: "pair-b", availableModes: [move, chill]), move)
    }
}
