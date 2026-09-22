import XCTest
@testable import OpenAdaptCore

final class ShoePairFeatureTests: XCTestCase {
    func testAutoLaceDefaultsOffAndRemembersOnlyCompleteChangesPerPair() {
        let suite = "OpenAdaptAutoLaceTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preference = SavedAutoLacePreference(defaults: defaults)
        XCTAssertFalse(preference.isEnabled(forPair: "first"))
        XCTAssertFalse(preference.record(true, forPair: "first", confirmations: [.confirmed(true), .unconfirmed("Failed")]))
        XCTAssertFalse(preference.isEnabled(forPair: "first"))
        XCTAssertTrue(preference.record(true, forPair: "first", confirmations: [.confirmed(true), .confirmed(true)]))
        XCTAssertTrue(SavedAutoLacePreference(defaults: defaults).isEnabled(forPair: "first"))
        XCTAssertFalse(preference.isEnabled(forPair: "second"))
        XCTAssertFalse(preference.record(false, forPair: "first", confirmations: [.confirmed(false), .applying]))
        XCTAssertTrue(preference.isEnabled(forPair: "first"))
        XCTAssertTrue(preference.record(false, forPair: "first", confirmations: [.confirmed(false), .confirmed(false)]))
        XCTAssertFalse(preference.isEnabled(forPair: "first"))
        preference.record(true, forPair: "first", confirmations: [.confirmed(true), .confirmed(true)])
        preference.clear(forPair: "first")
        XCTAssertFalse(preference.isEnabled(forPair: "first"))
    }
    func testSwitchRequiresBothShoesToConfirmTheSameSetting() {
        XCTAssertEqual(ShoePairFeatureState([.confirmed(true), .confirmed(true)]), .confirmed(true))
        XCTAssertEqual(ShoePairFeatureState([.confirmed(false), .confirmed(false)]), .confirmed(false))
        XCTAssertEqual(ShoePairFeatureState([.confirmed(true), .confirmed(false)]), .mixed)
        XCTAssertNil(ShoePairFeatureState([.confirmed(true), .confirmed(false)]).value)
    }

    func testUnknownAndPartialResultsCannotLookLikeOff() {
        for states: [ShoeFeatureConfirmation] in [[], [.confirmed(false)], [.unknown, .confirmed(false)],
                                                 [.unsupported, .confirmed(false)],
                                                 [.unconfirmed("Disconnected"), .confirmed(false)]] {
            XCTAssertNil(ShoePairFeatureState(states).value)
        }
        XCTAssertEqual(ShoePairFeatureState([.unconfirmed("Disconnected"), .confirmed(true)]), .unconfirmed)
    }

    func testWaitsForBothShoesBeforeFinishing() {
        XCTAssertEqual(ShoePairFeatureState([.confirmed(true), .applying]), .applying)
        XCTAssertEqual(ShoePairFeatureState([.confirmed(false), .reading]), .reading)
        XCTAssertNil(ShoePairFeatureState([.confirmed(false), .applying]).value)
    }
}
